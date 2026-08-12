# ghl-initial-sync — Backfill sekali sahaja (GHL → ISW)

Tarik **Contacts / Appointments / Orders LAMA** dari GHL masuk ISW — untuk
pesakit yang datang sebelum `ghl-booking-webhook` dipasang (atau semasa
downtime). Selepas backfill ni siap, `ghl-booking-webhook` kekalkan data
terkini secara realtime — fungsi ni **tak perlu dijalankan lagi** selepas
sekali (kecuali nak backfill julat tarikh baharu).

Guna semula logik teras yang SAMA dengan `ghl-booking-webhook`
(`_shared/ghl-sync.ts`) — padanan pesakit ikut telefon, dedup sesi KOB,
idempotent bayaran ikut `ghl_transaction_id`. Selamat dijalankan berulang
kali (retry-safe).

---

## 1. Set secret + deploy

Guna semula `GHL_ISW_TOKEN` / `GHL_ISW_LOCATION_ID` sedia ada (dari
`sync-ghl`/`ghl-inbox`) — **TIADA secret baharu diperlukan**.

```bash
supabase functions deploy ghl-initial-sync
```

> **TIADA** `--no-verify-jwt` — fungsi ni perlu token staff (JWT Supabase),
> sekat kepada `staff_role='super_admin'` sahaja (operasi bulk-write).

---

## 2. Sebelum jalankan — sahkan param API sebenar

GHL punya endpoint list (`/contacts/`, `/calendars/events`,
`/payments/orders`) — dokumentasi awam GHL tak selalu tunjuk nama param
cursor/tarikh dengan jelas. **Uji dulu dengan `limit` kecil** (curl terus,
bukan melalui fungsi ni) untuk sahkan bentuk response sebenar akaun anda:

```bash
curl -s "https://services.leadconnectorhq.com/contacts/?locationId=<GHL_ISW_LOCATION_ID>&limit=2" \
  -H "Authorization: Bearer <GHL_ISW_TOKEN>" -H "Version: 2021-07-28" | jq
```

Kalau nama field/param response berbeza dari yang dijangka dalam
`index.ts` (cth `contacts[]`, `dateAdded`, `contactName`), kemas kini
kod ikut response sebenar SEBELUM jalankan penuh.

---

## 3. Cara jalankan — curl-loop (ikut satu-satu, satu action setiap kali)

### a) Contacts
```bash
CURSOR='{}'
while true; do
  RES=$(curl -s -X POST "https://<PROJECT_REF>.supabase.co/functions/v1/ghl-initial-sync" \
    -H "Authorization: Bearer <STAFF_JWT>" -H "Content-Type: application/json" \
    -d "{\"action\":\"contacts\",\"cursor\":$CURSOR}")
  echo "$RES" | jq '{processed, total, hasMore, errors}'
  HAS_MORE=$(echo "$RES" | jq -r '.hasMore')
  [ "$HAS_MORE" != "true" ] && break
  CURSOR=$(echo "$RES" | jq -c '.cursor')
done
```

### b) Appointments — SATU kalendar setiap kali (6 kalendar KOB [WC])
```bash
# Dapatkan calendarId dulu:
curl -s "https://services.leadconnectorhq.com/calendars/?locationId=<GHL_ISW_LOCATION_ID>" \
  -H "Authorization: Bearer <GHL_ISW_TOKEN>" -H "Version: 2021-07-28" | jq '.calendars[] | {id,name}'
```
Ulang loop sama macam (a), tapi body `{"action":"appointments","calendarId":"<ID>","startTime":"...","endTime":"...","cursor":$CURSOR}`
— jalankan sekali bagi SETIAP kalendar (WC1-WC5, EG).

### c) Orders
Sama macam (a), `{"action":"orders","cursor":$CURSOR}`.

---

## 4. Apa yang berlaku setiap panggilan

Satu muka surat (≤100 rekod) diproses setiap panggilan (elak timeout Edge
Function). Setiap rekod:
1. `syncContactToPatient` — padan/cipta `psy_patients` ikut telefon (isi
   field kosong sahaja, tak timpa data sah).
2. (appointments) `syncAppointmentToSession` — cipta/kemas kini
   `psy_kob_sessions`, segerak `kob_status→'booked'` (guard sama macam
   `ghl-booking-webhook`).
3. (orders) `syncOrderToPayment` — cipta `psy_payments` (skip kalau
   `ghl_transaction_id` dah wujud ATAU status bukan paid/completed).

Pulangkan `{processed, total, errors, cursor, hasMore}` — `errors` senarai
rekod yang gagal (individu, tak gagalkan seluruh muka surat). Semak
`errors` selepas setiap panggilan.

## Nota & had

- Ini **bukan** cron/scheduled — jalankan manual, sekali, ikut keperluan.
- Kalau `errors` banyak selepas panggilan pertama, HENTIKAN loop dan
  siasat (kemungkinan nama field response tak padan — lihat §2).
- Endpoint appointments/orders GHL v2 kurang dieksploitasi berbanding
  `/contacts/`/`/conversations/` dalam projek ni — sahkan bentuk response
  sebenar sebelum backfill besar-besaran (§2).
