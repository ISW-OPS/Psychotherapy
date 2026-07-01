# 04 — Automasi & Edge Functions

[← Kembali ke indeks](README.md)

Logik server berjalan sebagai **Supabase Edge Functions** (Deno/TypeScript) di `supabase/functions/`. Automasi mesej WhatsApp/Email melalui **GoHighLevel (GHL)** dan dijadualkan dengan `pg_cron`.

---

## 1. Senarai Edge Functions

| Function | Guna |
|----------|------|
| `event-reminders` | **Enjin automasi utama** — 4 runner (lihat bawah). Dipacu cron. |
| `invite-staff` | Cipta akaun staf + hantar magic link set-password |
| `sync-ghl` | Penyegerakan ISW ↔ GoHighLevel (Fasa 1; belum deploy — perlu GHL IDs user) |
| `ghl-inbox` | Tarik mesej WhatsApp masuk dari GHL → `psy_wa_*` |
| `ghl-inbox-webhook` | Webhook terima mesej WhatsApp masa nyata dari GHL |

---

## 2. Mesej Automatik — `psy_auto_messages`

Rangka mesej automatik (dibina Fasa 1, 23 Jun 2026). Idea: **ganti hardcode dalam Edge Function dengan konfig dari DB** supaya boleh ubah di UI tanpa re-deploy.

**Jadual `psy_auto_messages`** — lajur penting:
- `key` (unik), `name`, `description`, `channel`
- `trigger_type`: `before_event` | `before_session` | `daily_reminder` | `on_action` | `recurring_broadcast`
- `minutes_before`, `send_at_time`
- `message_template` (placeholder `{nama}{acara}{masa}{lead}{pautan}{senarai}`)
- `days_of_week` (jsonb, 0=Ahad..6=Sabtu), `session_time`, `audience`, `package_ids`, `channels` (whatsapp/inapp/announcement/email)
- `last_broadcast_at` (dedup harian), `rule` (jsonb — ambang untuk alert)
- `is_active` (toggle)

RLS: staf baca, super_admin urus.

### UI — `roles/staff/auto-mesej.html`
Modul RBAC `auto_messages` (super_admin edit / manager view), dalam kumpulan nav **KOMUNIKASI**. Senarai + modal edit: template + chip sisip placeholder + pemilih masa ikut `trigger_type` + toggle aktif + pratonton WhatsApp langsung. Sokong jenis `recurring_broadcast` (pemilih hari + masa sesi + lead + link + saluran + sasaran).

> Editor medan `rule` (ambang alert) belum ada di UI — ubah via SQL buat masa ini.

---

## 3. `event-reminders` — 4 Runner

Satu Edge Function jalankan empat runner berasingan setiap kali cron cetus:

### Runner 1 — `runEventReminders`
Baca `psy_auto_messages` key=`event_reminder` (gate `is_active`, `minutes_before`). Hantar reminder WhatsApp sebelum acara. **LIVE di testing.**

### Runner 2 — `runBroadcasts` (recurring_broadcast)
Broadcast berulang ikut hari-dalam-minggu (cth Manzil Live Rab/Kha/Jum 8.45 pagi). Kira masa Malaysia (UTC+8), semak `days_of_week` + window (±10min vs `session_time − minutes_before`), dedup `last_broadcast_at` (claim DULU sebelum hantar elak double-send), hantar ke semua pesakit (tapis `package_ids`) — WA ber-batch 15 + loceng `psy_notifications` + cipta `psy_announcements` (expire hujung hari). Seed `manzil_live` (draf, off).
> ⚠️ Broadcast WA ke semua pesakit = volume besar. Uji dengan pakej ujian/diri sendiri dahulu.

### Runner 3 — `runCatatanHarianReminder` (daily_reminder)
Pada `send_at_time` (cth 20:00, window ±10min, dedup harian), hantar WA kepada pesakit **aktif** yang **belum** ada baris `psy_kepatuhan_log` untuk hari itu. Migrasi `20260625_catatan_harian_reminder.sql`. `is_active` kekal **false** — staf hidupkan bila GHL sedia.

### Runner 4 — `runKepatuhanAlerts` (daily_reminder, alert COACH) ⭐
Engine multi-check anti-ketidakpatuhan. Hujung hari, 1×/hari (claim `last_broadcast_at`), untuk tiap pesakit aktif yang ada coach → nilai **4 check** dan gabung jadi **satu alert** (senarai bullet):
1. **amalan** — per-item dari `psy_kepatuhan_log.jawapan`, kira hari item di bawah sasaran ≥ `min_days_short`
2. **checklist** — hari tak isi log ≥ `min_days_missing`
3. **skor** — purata skor mingguan (Pilihan B) < `min_score`
4. **vitals** — tiada `psy_vitals.reading_date` dalam `min_days_since` hari

Jika ada ≥1 isu → INSERT `psy_risk_alerts` (category=`kepatuhan`, created_by_name='Sistem (Auto-Kepatuhan)') + loceng + (email GHL — kini **dimatikan**). Dedup mingguan. Migrasi `20260626_kepatuhan_alerts.sql` (lajur `rule` + seed).

**Konfig `rule` (default):**
```json
{ "severity": "high", "window_days": 7,
  "email_from": "support@ibnusinawellness.com",
  "checks": {
    "amalan":    { "on": true, "min_days_short": 3 },
    "checklist": { "on": true, "min_days_missing": 3 },
    "skor":      { "on": true, "min_score": 80 },
    "vitals":    { "on": true, "min_days_since": 7 }
  } }
```

> **Keputusan user (23 Jun 2026):** `channels = ["inapp"]` SAHAJA — email coach **dimatikan** buat masa ini (makluman dalam sistem je: loceng + `risk.html`). Kod email kekal utuh; hidupkan = tambah `"email"` semula di channels.
> Check **ubat/herba** & **no-show coaching** ditangguh (tiada sumber data).

---

## 4. Status deploy automasi

| Komponen | Testing (`ipmemyiz`) | Production (`xmvqvq`) |
|----------|---------------------|----------------------|
| `psy_auto_messages` + migrasi | ✅ Siap & diuji | ⚠️ Sebahagian — perlu run migrasi penuh |
| `event-reminders` (4 runner) | ✅ Deployed v12, diuji end-to-end | ✅ Deployed (ada runner kepatuhan) |
| Cron `pg_cron` | ✅ Berfungsi | ✅ Dibetulkan (dulu rosak — URL salah + secret placeholder) |
| `is_active` runner 3 & 4 | **OFF** (staf hidupkan di UI) | **OFF** |

**Tinggal untuk production go-live automasi:**
1. Run migrasi auto-messages penuh (jika belum)
2. Deploy frontend repo (nav/UI/authGuard auto-live)
3. Assign coach ke pesakit aktif (ramai pesakit tiada coach)
4. Sahkan email coach (jika hidupkan email kelak)
5. Toggle `is_active=true` di UI bila sedia & diuji

> Rahsia cron prod & detail penuh: memori `project_auto_messages`.

---

## 5. Integrasi GoHighLevel (GHL)

3-fasa ISW ↔ GHL untuk WhatsApp KOB. **Fasa 1** = `sync-ghl` Edge Function dibina (belum deploy — perlu GHL location/calendar IDs user). Inbox WhatsApp (`ghl-inbox*`) tarik perbualan masuk ke `psy_wa_*` dan dipapar di `S inbox.html`. Hantar WA guna `type:'SMS'` di-route ke WhatsApp. Email guna domain khusus `ibnusinawellness.com` (sender `support@`).

(Detail: memori `project_ghl_integration`.)

---

## 6. Fasa 2 (ditangguh)

Aliran **dua-hala interaktif**: "3 hari sebelum rawatan tanya boleh hadir → kalau tak, tanya tarikh → auto-reschedule". Cadangan selamat: mesej dengan **pautan ke halaman reschedule in-app** (guna slot sah), BUKAN parse teks WhatsApp bebas (rapuh, risiko double-booking).

---

Seterusnya: [05 — Peranan & Akses →](05-peranan-akses.md)
