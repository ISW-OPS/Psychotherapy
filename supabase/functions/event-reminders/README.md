# event-reminders — Peringatan WhatsApp 1 jam sebelum acara

Hantar mesej WhatsApp (melalui GoHighLevel) kepada setiap pesakit yang
telah mendaftar acara, lebih kurang **1 jam sebelum** acara bermula.

```
pg_cron (tiap 15 min) ──► event-reminders ──► GHL Conversations API ──► WhatsApp pesakit
        (x-cron-secret)         │
                                └─ tandai psy_event_registrations.reminder_sent_at (dedup)
```

Idempotent: setiap pendaftaran hanya diperingat **sekali** (`reminder_sent_at`).
Acara dikira "due" bila mula dalam **50–70 minit** dari masa cron jalan.

---

## 1. Prasyarat GHL (sekali sahaja)

1. **Private Integration token** dengan scope: `contacts.write`,
   `contacts.readonly`, `conversations.write`, `conversations/message.write`.
2. Ambil **Location ID** sub-akaun ISW (= `cVOgqxddpXRzqaIXFkxl`).

> ⚠️ **Saluran hantar = `type:'SMS'`, BUKAN `type:'WhatsApp'`.** Saluran WhatsApp
> *rasmi* GHL klinik ini tidak disambung (WhatsApp masuk via peranti terpaut),
> jadi `type:'WhatsApp'` gagal dengan "WhatsApp not connected". Saluran **SMS**
> GHL klinik ni di-route ke WhatsApp — sama macam Edge Function `ghl-inbox` yang
> sudah disahkan jalan. Fungsi ni guna `type:'SMS'`. Jangan tukar ke 'WhatsApp'
> melainkan saluran WhatsApp rasmi disambung kemudian.
>
> Reuse secret **`GHL_ISW_TOKEN`** + **`GHL_ISW_LOCATION_ID`** sedia ada (sama
> dengan sync-ghl / ghl-inbox) — jangan cipta secret baru.

---

## 2. Set secrets + deploy

`GHL_ISW_TOKEN` + `GHL_ISW_LOCATION_ID` **sudah wujud** (dipakai sync-ghl /
ghl-inbox) — tak perlu set semula. Hanya tambah rahsia cron:

```bash
supabase secrets set CRON_SECRET="$(openssl rand -hex 24)"   # simpan untuk langkah 4

# Projek ISW guna CLI via npx (tiada Docker perlu):
npx supabase functions deploy event-reminders --no-verify-jwt --project-ref ipmemyizigwgivccytcu
```

> `--no-verify-jwt` sebab pemanggil ialah cron (guna `x-cron-secret`, bukan JWT).
> Nota: `ipmemyizigwgivccytcu` = projek **testing**. Untuk production (xmvqvq),
> deploy ke project-ref production & set secret di sana.

`SUPABASE_URL` & `SUPABASE_SERVICE_ROLE_KEY` sudah auto-tersedia dalam runtime
Edge Function — tak perlu set.

---

## 3. Migration DB

Run `supabase/migrations/20260622_pengumuman_acara_updates.sql` (mengandungi
lajur `reminder_sent_at` + perubahan Pengumuman/Acara lain). Idempotent.

---

## 4. Jadualkan (pg_cron + pg_net)

Aktifkan extension **pg_cron** & **pg_net** (Dashboard → Database → Extensions),
kemudian run SQL berikut (ganti `<PROJECT_REF>` & `<CRON_SECRET>`):

```sql
select cron.schedule('event-reminders', '*/15 * * * *', $$
  select net.http_post(
    url     := 'https://<PROJECT_REF>.supabase.co/functions/v1/event-reminders',
    headers := jsonb_build_object('Content-Type','application/json','x-cron-secret','<CRON_SECRET>'),
    body    := '{}'::jsonb
  );
$$);
```

Tiada pg_cron? Guna cron luar (cth cron-job.org) hit URL yang sama setiap 15 min
dengan header `x-cron-secret`.

---

## 5. Uji manual

```bash
curl -s -X POST "https://<PROJECT_REF>.supabase.co/functions/v1/event-reminders" \
  -H "Content-Type: application/json" -H "x-cron-secret: <CRON_SECRET>" | jq
```

Cipta acara ujian `published` dengan `start_at` ~60 min dari sekarang, daftar
seorang pesakit (ada no. telefon sah), kemudian panggil fungsi — semak WhatsApp.
Log: `supabase functions logs event-reminders`.

Respons contoh: `{ "success": true, "due": 1, "candidates": 1, "sent": 1, "skipped": 0, "errors": [] }`

---

## Nota & had

- **Join key = no. telefon** (E.164). Pesakit tiada phone → di-skip (dilog).
- **Sekali peringat** setiap pendaftaran. Tukar tingkap/masa? Ubah
  `REMIND_BEFORE_MIN` / `WINDOW_HALF_MIN` dalam [index.ts](index.ts) (pastikan
  tingkap penuh ≥ selang cron supaya tiada acara terlepas).
- Hanya acara `status='published'` diproses.

### Alternatif (jika perlu template WhatsApp diluluskan)
Ganti `sendWhatsApp()` dengan panggilan yang **menambah contact ke GHL Workflow**
(yang menghantar template WhatsApp), atau guna endpoint hantar-template GHL.
Logik penjadualan + dedup kekal sama.
