# Fasa 2 — Pengesahan Sesi Rawatan

Sebelum setiap sesi rawatan, sistem hantar **peringatan WhatsApp** (teks
sahaja — tiada butang, tiada pautan wajib) minta pesakit **balas** untuk
sahkan kehadiran. Staff baca balasan tu sendiri dan **tandakan dalam sistem**
(atau tukar tarikh guna alat sedia ada). Bila tinggal **≤ 24 jam** dan masih
belum ditandakan sahkan, **coach dapat alert** supaya boleh follow-up.

Tiada auto-parse teks WhatsApp — staff yang tafsir balasan & buat tindakan
(ringkas & selamat, elak salah faham auto-sistem).

## Aliran

1. **Peringatan** (default 3 hari sebelum, jam 10:00) — enjin cari sesi
   berstatus `booked` yang belum ditandakan sahkan → hantar **WhatsApp**:
   > *"Peringatan sesi rawatan anda: Minggu 10 Sesi 1, Jumaat 15 Mei · 2:30
   > PTG. Boleh hadir? Sila balas mesej ini untuk sahkan kehadiran."*
   Turut hantar **notifikasi in-app** (loceng) dengan pautan `plan.html` —
   laluan **pilihan** untuk pesakit yang guna app terus sahkan sendiri.
2. **Pesakit balas** dalam WhatsApp (teks bebas — "ya boleh", "tak boleh nak
   tukar", dsb). Ini di luar sistem; staff yang baca.
3. **Staff bertindak** di `roles/staff/kehadiran.html` → panel "Pengesahan
   Sesi Akan Datang":
   - Balasan **boleh hadir** → klik **"Tandakan Disahkan"**.
   - Balasan **nak tukar tarikh** → klik **"Tukar Tarikh"** → buka
     `plan-week.html` (alat sedia ada) untuk set tarikh baharu.
4. **Had 24 jam** — bagi pesakit yang guna app sendiri (`plan.html`), tukar
   tarikh dikunci kurang 24 jam sebelum sesi. (Staff masih boleh tukar bila-
   bila melalui `plan-week.html`.)
5. **Escalation** — sesi ≤ 24 jam & masih belum ditandakan sahkan →
   `psy_risk_alerts` (category `temujanji`) + loceng kepada coach. Dedup
   1×/sesi.

## Komponen

| Bahagian | Fail |
|---|---|
| Migration (lajur + config) | `database/step91_session_confirm.sql` |
| Enjin (runner `runSessionConfirm`) | `supabase/functions/event-reminders/index.ts` |
| Panel staff (tandakan/tukar tarikh) | `roles/staff/kehadiran.html` |
| UI pesakit pilihan (self-serve app) | `roles/patient/plan.html` (`?confirm=`) |
| Tukar tarikh (alat sedia ada) | `roles/staff/plan-week.html` |

**Lajur baru** `psy_plan_weekly_progress`: `confirm_reminder_sent_at`,
`confirm_escalated_at` (dedup per-sesi). `patient_confirmed*` sudah sedia ada.
Reschedule (staff atau pesakit) reset flag ini → kitaran peringatan/escalation
bermula semula untuk tarikh baharu.

**Config** `psy_auto_messages` key `session_confirm` (default **OFF**):
- `rule.lead_days` (3) · `rule.deadline_hours` (24) · `rule.escalate` (on, medium)
- `send_at_time` (10:00) · `channels` (`whatsapp`,`inapp`)
- Template WA — edit terus di sini (tiada pautan diperlukan dalam mesej).

## Cara Test

**A) Test hantar SATU mesej (tanpa tunggu cron/jadual):**
Guna `roles/staff/test-automation.html` → pilih template "Pengesahan Sesi
Rawatan" → pilih pesakit ujian → saluran WhatsApp → hantar. Ini hantar
**terus** (bukan tunggu jam 10 pagi), bagus untuk semak wording & format.
⚠️ Ini hantar WhatsApp **sebenar** — guna nombor telefon sendiri/pesakit ujian.

**B) Test aliran PENUH (peringatan + panel staff + escalation):**
1. Di Supabase (testing project), tempah satu sesi pesakit ujian 3 hari akan
   datang (`psy_plan_weekly_progress`, status `booked`).
2. Set `psy_auto_messages.is_active = true` untuk key `session_confirm`.
3. Cetus function `event-reminders` manual (pg_cron trigger atau panggil URL
   Edge Function terus dengan header `x-cron-secret`).
4. Semak: WhatsApp masuk ke nombor ujian; loceng in-app pesakit ada.
5. Buka `roles/staff/kehadiran.html` → panel "Pengesahan Sesi Akan Datang" →
   sesi tu patut muncul status **⏳ Menunggu**. Klik **Tandakan Disahkan** →
   status tukar ke **✅ Disahkan**.
6. Untuk uji escalation: tempah sesi ujian **< 24 jam** dari sekarang, biar
   `patient_confirmed` kosong, cetus function semula → semak alert masuk ke
   `psy_risk_alerts` + loceng coach (kalau pesakit ujian ada `coach_id`).
7. Set `is_active = false` semula selepas selesai uji (elak hantar berulang
   ke pesakit sebenar sebelum sedia).

## Langkah Deploy (ops)

1. **Run SQL** `database/step91_session_confirm.sql` di **TESTING** & **PROD**
   (idempotent). Mesti run **sebelum/serentak** deploy frontend.
2. **Redeploy Edge Function** `event-reminders` ke **TESTING** & **PROD**
   (versi baharu ada `runSessionConfirm`). Cron 15-min sedia ada memanggilnya.
3. **Uji** ikut langkah "Cara Test" di atas.
4. **Aktifkan**: set `is_active = true` (via UI auto-mesej.html atau SQL) bila
   sedia untuk pesakit sebenar. **Kekal OFF** sehingga diuji hujung-ke-hujung.

## Nota

- Auto-caj RM425 **tidak** dilaksana automatik (kekal manual — lihat rule
  extension berbayar sedia ada). Escalation hanya maklum coach.
- Tiada butang Ya/Tidak dalam WhatsApp itu sendiri (perlu WhatsApp
  interactive template via GHL, belum dibina — kos/kerja tambahan berasingan
  jika Tuan nak upgrade kemudian).
- Penambahbaikan lanjut (belum buat): editor medan `rule` khusus di UI
  auto-mesej, model inventori slot (had kapasiti/double-book).
