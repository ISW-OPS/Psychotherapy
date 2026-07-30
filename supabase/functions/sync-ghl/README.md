# sync-ghl — Fasa 1: Sync status KOB + tarikh booking (ISW → GoHighLevel)

Setiap kali `psy_patients.kob_status` bertukar, status itu auto-push ke GHL:
contact di-upsert ikut no. telefon, custom fields diisi, dan Opportunity
digerakkan ke pipeline stage yang padan. Closer kekal di inbox WhatsApp GHL.

Setiap kali patient **tempah / reschedule / batal** slot KOB
(`psy_kob_sessions`), tarikh sesi auto-masuk custom field
`kob_session_date` pada contact (cth: `26/07/2026, 10:00 am (online)`).

```
psy_patients UPDATE ───┐
   (kob_status)        ├─► Supabase DB Webhook ──► sync-ghl ──► GHL API v2
psy_kob_sessions ──────┘        (x-sync-secret)                 (contact + opportunity)
   (INSERT/UPDATE)
```

---

## 1. Sediakan di GHL dahulu

### a) Custom Fields (Settings → Custom Fields)
Cipta field berikut. **Key mesti sama** macam dalam `index.ts` (`CF`):

| Nama paparan        | Key (FieldKey)         |
|---------------------|------------------------|
| KOB Stage           | `kob_stage`            |
| KOB Status (raw)    | `kob_status_raw`       |
| Pakej KOB           | `kob_package`          |
| Pakej Tamat         | `kob_package_expires`  |
| ISW MRN             | `isw_mrn`              |
| Tarikh Sesi KOB     | `kob_session_date`     |

### b) Pipeline (Settings → Pipelines)
Cipta pipeline "KOB" dengan stages yang padan dengan setiap `kob_status`.

### c) Private Integration token (Settings → Private Integrations)
Scope minimum: `contacts.write`, `contacts.readonly`, `opportunities.write`,
`opportunities.readonly`. Salin token (`pit-...`).

---

## 2. Dapatkan ID pipeline + stages

Jalankan (ganti TOKEN & LOCATION_ID):

```bash
curl -s "https://services.leadconnectorhq.com/opportunities/pipelines?locationId=LOCATION_ID" \
  -H "Authorization: Bearer TOKEN" -H "Version: 2021-07-28" | jq
```

Salin `pipeline.id` → `GHL_PIPELINE_ID`, dan setiap `stages[].id` →
isikan ke dalam `STAGE_MAP` di [index.ts](index.ts) (ganti semua `FILL_STAGE_*`).

---

## 3. Set secrets + deploy

```bash
supabase secrets set GHL_ISW_TOKEN="pit-xxxxx"
supabase secrets set GHL_ISW_LOCATION_ID="xxxxx"
supabase secrets set GHL_PIPELINE_ID="xxxxx"
supabase secrets set SYNC_WEBHOOK_SECRET="$(openssl rand -hex 24)"   # simpan untuk langkah 4

supabase functions deploy sync-ghl --no-verify-jwt
```

> `--no-verify-jwt` sebab pemanggil ialah DB webhook (guna `x-sync-secret`,
> bukan JWT pengguna).

---

## 4. Pasang Database Webhook (2 webhook, function sama)

Supabase Dashboard → **Database → Webhooks → Create** (buat DUA kali):

**Webhook 1 — status KOB:**
- **Table:** `psy_patients`
- **Events:** `Update`, `Insert`

**Webhook 2 — tarikh booking:**
- **Table:** `psy_kob_sessions`
- **Events:** `Update`, `Insert`

Kedua-duanya guna tetapan sama:
- **Type:** HTTP Request → `POST`
- **URL:** `https://<PROJECT_REF>.supabase.co/functions/v1/sync-ghl`
- **HTTP Headers:**
  - `Content-Type: application/json`
  - `x-sync-secret: <nilai SYNC_WEBHOOK_SECRET dari langkah 3>`

Webhook hantar payload `{ type, table, record, old_record }`. Function skip
kalau `kob_status` / tarikh sesi tak berubah, jadi update lain tak spam GHL.
(Jangan tambah event `Delete` pada `psy_kob_sessions` — rebooking buang baris
lama dulu sebelum insert baru; INSERT baru itu sudah bawa tarikh terkini.)

---

## 5. Uji

Tukar `kob_status` seorang pesakit ujian (ada no. telefon sah) dalam Supabase,
kemudian semak di GHL: contact wujud, custom field `KOB Stage` terisi, dan
Opportunity berada di stage betul.

Uji tarikh booking: login sebagai patient ujian → tempah slot KOB di
`kob.html` → semak custom field **Tarikh Sesi KOB** pada contact GHL
(`26/07/2026, 10:00 am (fizikal)`). Reschedule → tarikh bertukar.
Batal (staff set `status='cancelled'`) → field dikosongkan.

Lihat log: `supabase functions logs sync-ghl`.

---

## Nota & had (Fasa 1)

- **Sehala sahaja** (ISW → GHL). Perubahan di GHL tidak balik ke ISW lagi (Fasa 3).
- **Join key = no. telefon** (E.164). Pastikan KYC/patient ada phone betul.
  Tiada phone → di-skip (dilog), bukan error.
- Tidak menyentuh UI sedia ada — fully backend.
- Custom field guna `key`/`field_value`. Jika tenant GHL anda perlukan `id`,
  tukar kepada `{ id, value }` selepas dapat field id dari
  `GET /locations/{locationId}/customFields`.
