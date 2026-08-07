# ghl-booking-webhook — Push booking + payment "Paid" (GHL → ISW)

Bila closer/sales di GHL sahkan pesakit dah **bayar** dan **tempah tarikh**
(KOB atau temujanji), GHL push maklumat tu masuk ISW: cipta rekod pesakit
baru (kalau belum wujud, dipadan ikut no. telefon) + cipta satu slot sesi
KOB (`psy_kob_sessions`, status `booked`) pada tarikh yang dihantar.

```
GHL Workflow (trigger: tag ditambah / appointment dibuat)
   └─► Webhook action ──► ghl-booking-webhook ──► psy_patients (upsert ikut phone)
                                (x-ghl-booking-secret)   └─► psy_kob_sessions (INSERT)
```

**Fasa 1 — sehala GHL → ISW.** Tak sentuh sync-ghl (ISW → GHL) yang sedia
ada; lepas rekod dicipta di sini, sync-ghl akan overwrite balik status ke
GHL macam biasa bila `kob_status` berubah seterusnya (contoh bila pesakit
isi KYC).

---

## 1. Sediakan di GHL

Booking sebenar berlaku di **Calendars → Meetings**, group **"KOB [WC]"**
(6 kalendar: KONSULTASI OVERHAUL BODY WC1-WC5, EG — 1j30m setiap satu).
Pesakit book terus di funnel; ISW **tidak** menguruskan slot/kapasiti,
cuma terima & papar tarikh yang GHL dah confirm.

**Trigger:** GHL Workflow
- **Trigger:** *Appointment Status* (atau *Customer Booked Appointment*)
- **Calendar filter:** kalendar dalam group `KOB [WC]` (semua 6, atau ikut
  keperluan)
- **(opsyenal, lapisan keselamatan tambahan)** Tambah condition: custom
  field `ISW STATUS` (key `contact.status`) = `SU KOB` — field dropdown
  ni memang penanda "dah bayar + dah book" di GHL, jadi boleh pastikan
  webhook hanya push bila status betul-betul `SU KOB` (bukan `SU KOB TBC`
  / `SU KOB A` yang mungkin belum final).
- **Action:** Webhook

Body webhook (JSON) — map field GHL ke bentuk ni:

```json
{
  "phone": "{{contact.phone}}",
  "full_name": "{{contact.full_name}}",
  "email": "{{contact.email}}",
  "scheduled_at": "{{appointment.start_time}}",
  "mode": "f2f"
}
```

- `phone` — **wajib**. Kunci padanan pesakit (9 digit terakhir).
- `scheduled_at` — **wajib**, ISO 8601 (cth GHL appointment merge field, atau
  custom field tarikh yang closer isi manual).
- `mode` — opsyenal, `"f2f"` (default) atau `"online"`.
- `full_name` / `email` — opsyenal, hanya dipakai kalau pesakit baru dicipta.

---

## 2. Set secret + deploy

```bash
supabase secrets set GHL_BOOKING_WEBHOOK_SECRET="$(openssl rand -hex 24)"
supabase functions deploy ghl-booking-webhook --no-verify-jwt
```

> `--no-verify-jwt` sebab pemanggil GHL, bukan pengguna Supabase.

Di GHL Workflow → Webhook action:
- **URL:** `https://<PROJECT_REF>.supabase.co/functions/v1/ghl-booking-webhook?secret=<GHL_BOOKING_WEBHOOK_SECRET>`
- **Method:** POST, **Content-Type:** application/json

---

## 3. Apa yang berlaku bila dipanggil

1. Padan pesakit sedia ada ikut 9 digit terakhir telefon.
2. **Tiada padanan** → cipta `psy_patients` baru: `status='pending_kyc'`,
   `kob_status='paid'` (makna sedia ada dalam skema: *"Sudah bayar
   (bayaran luaran/GHL), KYC belum hantar"*), `referral_source='GHL'`.
   MRN auto-jana.
3. Cipta `psy_kob_sessions` (`status='booked'`) pada `scheduled_at` yang
   dihantar. Kalau webhook sama tercetus dua kali (retry GHL), tak cipta
   slot berganda — dikesan ikut `patient_id` + `scheduled_at`. Kalau
   tarikh **berbeza** dari sesi aktif sedia ada (reschedule di GHL), sesi
   `booked`/`reschedule` lama dibuang dulu supaya cuma satu KOB aktif.
4. **Segerak `psy_patients.kob_status` → `'booked'`** (kecuali pesakit dah
   lebih jauh — `hadir`/`package_recommended`/`package_paid`/`completed`,
   tak diturunkan). Ini penting: `kob.html` guna `kob_status` untuk tentukan
   papar kalendar tempah-sendiri ISW **atau** skrin "Sesi KOB Disahkan"
   (guna tarikh dari `psy_kob_sessions`). Tanpa langkah ni, pesakit akan
   nampak kalendar ISW walaupun tarikh GHL dah wujud dalam DB.
5. Log ke `psy_audit_log` (`action='ghl_booking.received'`) untuk jejak.
6. Pesakit lengkapkan KYC bila login kali pertama (`kyc.html`) — alur
   sedia ada tak berubah. `enforceKyc()` (GATE 1, `_shared.js`) pastikan
   pesakit KYC dulu sebelum boleh masuk `kob.html` langsung, tak kira
   `kob_status`.

## Nota & had

- Pesakit yang dicipta di sini **belum ada akaun login** (`user_id IS
  NULL`) — sama macam pesakit `created_by_staff`. Bila pesakit signup
  sendiri kelak, auto-link semasa ini padan ikut **IC**, bukan telefon —
  kalau GHL contact tiada IC, pesakit mungkin ter-duplicate semasa
  signup. Kalau ni jadi isu lepas ujian, perlu lanjutkan logik auto-link
  sedia ada (`patients.html`) untuk padan ikut telefon juga.
- Tak sahkan tarikh `scheduled_at` lawan `psy_kob_slot_config` (slot
  aktif) — GHL/closer bertanggungjawab pilih slot sah semasa booking.
