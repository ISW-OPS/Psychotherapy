# ghl-booking-webhook — Push booking + payment + contact (GHL → ISW)

Bila closer/sales di GHL sahkan pesakit dah **bayar**, **tempah tarikh**
(KOB atau temujanji), atau **kemas kini maklumat**, GHL push maklumat tu
masuk ISW. Satu fungsi, tiga jenis event (`event` dalam body JSON):

| `event` | Bila dicetus | Apa yang berlaku di ISW |
|---|---|---|
| `appointment` (default — tiada field = ni) | Closer sahkan booking KOB | Padan/cipta pesakit + cipta/kemas kini `psy_kob_sessions` (`status='booked'`) |
| `order` | Closer sahkan bayaran yuran KOB | Padan/cipta pesakit + cipta rekod `psy_payments` (`payment_method='ghl'`) + `kob_status→'paid'` |
| `contact` | Maklumat pesakit dikemas kini di GHL | Padan/cipta pesakit sahaja (tiada sesi/bayaran disentuh) |

```
GHL Workflow (Appointment Status / Order Submitted / Contact Changed)
   └─► Webhook action ──► ghl-booking-webhook ──► psy_patients (padan/cipta ikut phone)
              (x-ghl-booking-secret)                ├─► psy_kob_sessions (event=appointment)
                                                     └─► psy_payments    (event=order)
```

**Sehala GHL → ISW.** Tak sentuh `sync-ghl` (ISW → GHL) yang sedia ada;
lepas rekod dicipta di sini, `sync-ghl` akan overwrite balik status ke
GHL macam biasa bila `kob_status` berubah seterusnya (contoh bila pesakit
isi pendaftaran/KYC).

---

## 1. Sediakan di GHL — TIGA Workflow

Booking sebenar berlaku di **Calendars → Meetings**, group **"KOB [WC]"**
(6 kalendar: KONSULTASI OVERHAUL BODY WC1-WC5, EG — 1j30m setiap satu).
Pesakit book terus di funnel; ISW **tidak** menguruskan slot/kapasiti
untuk booking jenis ini, cuma terima & papar tarikh yang GHL dah confirm
(booking sendiri dalam ISW, `kob.html`, kekal berasingan — pesakit yang
tak melalui closer boleh terus tempah slot ISW seperti biasa).

### a) Workflow "Appointment" (SEDIA ADA — tak perlu ubah)
- **Trigger:** *Appointment Status* (atau *Customer Booked Appointment*),
  filter kalendar `KOB [WC]`
- **(opsyenal)** condition custom field `ISW STATUS` = `SU KOB`
- **Action:** Webhook, body:
```json
{
  "event": "appointment",
  "phone": "{{contact.phone}}",
  "full_name": "{{contact.full_name}}",
  "email": "{{contact.email}}",
  "scheduled_at": "{{appointment.start_time}}",
  "mode": "f2f"
}
```
> Field `"event"` opsyenal — kalau Workflow sedia ada anda TAK menghantar
> field ni langsung, fungsi anggap `appointment` secara default (100%
> keserasian ke belakang, tiada perubahan tingkah laku).

- `phone` — **wajib**. Kunci padanan pesakit (9 digit terakhir).
- `scheduled_at` — **wajib**, ISO 8601.
- `mode` — opsyenal, `"f2f"` (default) atau `"online"`.

### b) Workflow "Order Submitted" (BAHARU)
- **Trigger:** *Order Submitted* / *Invoice Paid* (ikut mana tersedia di
  akaun anda), filter produk/pipeline yuran KOB
- **Action:** Webhook, URL & secret **sama** macam (a), body:
```json
{
  "event": "order",
  "phone": "{{contact.phone}}",
  "full_name": "{{contact.full_name}}",
  "email": "{{contact.email}}",
  "order_id": "{{order.id}}",
  "amount": "{{order.amount}}",
  "status": "{{order.status}}"
}
```
- `order_id` — **wajib**, jadi kunci idempotency (`ghl_transaction_id`) —
  webhook retry dengan `order_id` sama TIDAK cipta rekod bayaran berganda.
- `status` — **wajib**; hanya diproses kalau nilai (case-insensitive)
  salah satu `paid`/`completed`/`succeeded`/`success` — status lain
  dilog & dilangkau (contoh `pending`/`refunded`).
- `amount` — jumlah RM, disimpan terus ke `psy_payments.total`.

### c) Workflow "Contact Changed" (BAHARU)
- **Trigger:** *Contact Changed* / *Contact Updated*
- **Action:** Webhook, URL & secret **sama**, body:
```json
{
  "event": "contact",
  "phone": "{{contact.phone}}",
  "full_name": "{{contact.full_name}}",
  "email": "{{contact.email}}",
  "ic_number": "{{contact.custom_field_ic}}",
  "address": "{{contact.custom_field_address}}",
  "emergency_contact_name": "{{contact.custom_field_emergency_name}}",
  "emergency_contact_phone": "{{contact.custom_field_emergency_phone}}"
}
```
- Kemaskini pesakit **HANYA kalau field tempatan kosong** — tak timpa
  data yang pesakit/staff dah sahkan (borang pendaftaran/KYC ialah
  sumber kebenaran lebih tinggi selepas dihantar).
- **Field custom (`ic_number`/`address`/`emergency_contact_*`) OPSYENAL**
  — hantar hanya kalau closer memang kumpul maklumat ni di GHL sebagai
  custom field pada contact. Ganti `{{contact.custom_field_ic}}` dll
  dengan merge field SEBENAR ikut nama custom field di akaun GHL anda
  (Settings → Custom Fields — semak nama/key sebenar, ia lain-lain ikut
  setup). Field yang tak dihantar/tiada nilai akan diabaikan (bukan
  ditimpa dengan kosong).
- **Kesan:** nilai ni **PRA-ISI SAHAJA** borang pendaftaran ISW
  (`roles/patient/pendaftaran.html` baca terus dari `psy_patients` bila
  pesakit belum pernah hantar borang — lihat fungsi `fillForm(base)`
  dalam fail tu). Pesakit **tetap** kena semak, edit kalau perlu, dan
  hantar sendiri (termasuk tick consent PDPA) — TIDAK auto-lulus/auto-
  hantar borang KYC dari data GHL.

---

## 2. Set secret + deploy

```bash
supabase secrets set GHL_BOOKING_WEBHOOK_SECRET="$(openssl rand -hex 24)"
supabase functions deploy ghl-booking-webhook --no-verify-jwt
```

> `--no-verify-jwt` sebab pemanggil GHL, bukan pengguna Supabase. Secret
> SAMA untuk ketiga-tiga Workflow (a/b/c) — satu URL, satu rahsia.

Di setiap GHL Workflow → Webhook action:
- **URL:** `https://<PROJECT_REF>.supabase.co/functions/v1/ghl-booking-webhook?secret=<GHL_BOOKING_WEBHOOK_SECRET>`
- **Method:** POST, **Content-Type:** application/json

---

## 3. Apa yang berlaku bila dipanggil

**Semua event** mula dengan padan pesakit ikut 9 digit terakhir telefon
(`phone`/`emergency_contact_phone`). Tiada padanan → cipta `psy_patients`
baru: `status='pending_kyc'`, `kob_status='paid'`, `referral_source='GHL'`,
MRN auto-jana, `user_id IS NULL` (belum ada akaun login).

**`event=appointment`** — cipta/kemas kini `psy_kob_sessions`
(`status='booked'`) pada `scheduled_at`. Dedup ikut `patient_id` +
`scheduled_at` (retry-safe). Tarikh **berbeza** dari sesi aktif sedia ada
(reschedule) → sesi `booked`/`reschedule` lama dibuang dulu supaya cuma
satu KOB aktif. Segerak `kob_status→'booked'` (tak diturunkan kalau
pesakit dah `hadir`/`package_recommended`/`package_paid`/`completed`).

**`event=order`** — cipta `psy_payments` (`payment_method='ghl'`,
`ghl_transaction_id=order_id`, `status='completed'`) — kini **NAMPAK**
dalam resit pesakit (`sejarah-pembayaran.html`) & reconciliation staff
(`payment-admin.html`, kolum "Ref GHL"). Segerak `kob_status→'paid'`
(guard sama macam di atas).

**`event=contact`** — padan/cipta pesakit sahaja, tiada sesi/bayaran.

Semua event log ke `psy_audit_log` (`action='ghl_booking.received'` /
`'ghl_order.received'` / `'ghl_contact.received'`), best-effort (gagal
log tak gagalkan webhook).

Pesakit lengkapkan pendaftaran (KYC) bila login kali pertama
(`pendaftaran.html`) — alur sedia ada tak berubah. `enforceKyc()` (GATE 1,
`roles/patient/_shared.js`) pastikan pendaftaran dulu sebelum boleh masuk
`kob.html`, tak kira `kob_status`.

## Nota & had

- Pesakit yang dicipta di sini **belum ada akaun login** (`user_id IS
  NULL`) — sama macam pesakit `created_by_staff`. Bila pesakit signup
  sendiri kelak, auto-link semasa ini padan ikut **IC**, bukan telefon —
  kalau GHL contact tiada IC, pesakit mungkin ter-duplicate semasa
  signup. Kalau ni jadi isu lepas ujian, perlu lanjutkan logik auto-link
  sedia ada (`patients.html`) untuk padan ikut telefon juga.
- Tak sahkan tarikh `scheduled_at` lawan `psy_kob_slot_config` (slot
  aktif) — GHL/closer bertanggungjawab pilih slot sah semasa booking.
- `event=order` cipta rekod bayaran untuk **yuran KOB sahaja**. Bayaran
  pakej (selepas doktor cadang) kekal melalui HitPay
  (`payment.html`/`payments-initiate`/`payments-webhook`) — TIDAK diubah.
- Pesakit lama yang datang dari GHL SEBELUM Workflow (b)/(c) dipasang
  tiada rekod bayaran/kemaskini kontak — guna `ghl-initial-sync` (fungsi
  berasingan) untuk backfill sekali sahaja.
