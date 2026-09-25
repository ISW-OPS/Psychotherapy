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

**Nota `kob_code`/`full_name` — DISAHKAN 25 Sept 2026:** Workflow "SU KOB
Auto ID" GHL letak kod KOB terus dalam field **`first_name`** contact
(cth. `"KOB'26-000139"`), nama sebenar dalam **`last_name`** (cth.
`"Pn Syamira"`) — DUA field berasingan, bukan digabung dalam satu field
nama macam anggapan asal. Jadi:
```json
"full_name": "{{contact.last_name}}",
"kob_code":  "{{contact.first_name}}"
```
`kob_code` → terus ke `psy_patients.ghl_kob_code` (medan "Kod KOB" —
**BUKAN** `reference_code`/"Kod Pesakit" sedia ada, tu diisi lepas pesakit
signup pakej OB, tujuan lain). Papar di kob-list.html (kolum "Kod KOB") &
patient-hub.html (badge "KOD KOB").

*Fallback (contact lama/laluan lain):* kalau `kob_code` TAK dihantar tapi
`full_name` masih format gabungan lama (`"KOB'26-000139. Pn Syamira"`),
fungsi cuba auto-asingkan kod tu drpd nama (corak huruf+`'`+2digit-
3~6digit). `kob_code` eksplisit **diutamakan** bila kedua-dua wujud.

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
- **Action:** Webhook, body (medan teras + medan pesakit opsyenal — lihat
  senarai penuh di bawah):
```json
{
  "event": "appointment",
  "phone": "{{contact.phone}}",
  "full_name": "{{contact.last_name}}",
  "kob_code": "{{contact.first_name}}",
  "email": "{{contact.email}}",
  "scheduled_at": "{{appointment.start_time}}",
  "mode": "{{contact.mod_sesi_kob}}",
  "closer": "{{appointment.booked_by}}",
  "collector": "{{contact.collector_kob}}",
  "contact_id": "{{contact.id}}",
  "ic_number": "{{contact.no_ic}}",
  "date_of_birth": "{{contact.date_of_birth}}",
  "gender": "{{contact.gender}}",
  "marital_status": "{{contact.status_perkahwinan}}",
  "occupation": "{{contact.kerja__syarikat}}",
  "address": "{{contact.address1}}",
  "postcode": "{{contact.postal_code}}",
  "city": "{{contact.city}}",
  "state": "{{contact.state}}",
  "emergency_contact_name": "{{contact.nama_waris_penjaga}}",
  "emergency_contact_phone": "{{contact.no_telefon_waris_penjaga}}",
  "emergency_contact_relationship": "{{contact.hubungan_waris_pesakit}}",
  "emergency_contact_email": "{{contact.email_waris_penjaga}}",
  "peranan_pendaftar": "{{contact.peranan_pendaftar}}",
  "borang_isi_sebagai": "{{contact.anda_mengisi_borang_ini_sebagai}}"
}
```
> Field `"event"` opsyenal — kalau Workflow sedia ada anda TAK menghantar
> field ni langsung, fungsi anggap `appointment` secara default (100%
> keserasian ke belakang, tiada perubahan tingkah laku).
>
> Senarai di atas dah disahkan padan dgn merge tag SEBENAR akaun GHL ISW
> (semak bersama 25 Sept 2026). `su_deliverables` (pakej) & `isw_mrn`
> **SENGAJA tak dihantar** — pakej dicadang doktor semasa sesi KOB
> (bukan dari GHL), MRN dijana sendiri oleh sistem kita.

- `phone` — **wajib**. Kunci padanan pesakit (9 digit terakhir).
- `scheduled_at` — **wajib**, ISO 8601.
- `kob_code` — opsyenal, **DISAHKAN** (lihat nota di atas). Sumber utama
  kod KOB — utamakan drpd fallback auto-parse `full_name`.
- `mode` — opsyenal. `{{contact.mod_sesi_kob}}` ("Mod Sesi KOB", field GHL
  khusus utk ni — bukan `isw_location` generik). Fungsi auto-kesan (teks
  mengandungi "online"/"virtual"/"zoom" → `online`, selain itu → `f2f`)
  kekal jalan tak kira format nilai field ni (pilihan tetap ke teks bebas).
- `gender` — opsyenal. `{{contact.gender}}` (medan RADIO GHL) — fungsi
  auto-padan `M`/`Male`/`Lelaki`/`L` → `M`, `F`/`Female`/`Perempuan`/`P`
  → `F`. Nilai lain diabaikan (bukan disimpan sbg sampah).
- `closer` — opsyenal. Label staff GHL yang buat/sahkan booking
  (`{{appointment.booked_by}}`, cth. `"T103 SABRINA"`) — disimpan sbg
  **teks** ke `psy_kob_sessions.closer_name`, dipapar di kolum **Closer**.
  **Disahkan.** (Alias diterima: `booked_by`/`bookedBy`.)
- `collector` — opsyenal. Label staff GHL (`{{contact.collector_kob}}`,
  field khusus "Collector KOB" — **DISAHKAN 25 Sept 2026**, gantikan
  `owner_name` yg dipakai sementara sebelum ni) — disimpan sbg **teks** ke
  `psy_kob_sessions.collector_name`, dipapar di kolum **Collector**. (Alias
  diterima: `owner_name`/`ownerName`/`collector_name`, utk keserasian
  kalau ada Workflow lama guna tag tu.)
  Kedua-dua `closer`/`collector` TIADA padanan ke akaun staff ISW
  (`closer_id`/`collector_id` kekal kosong) sebab staff GHL ni tak
  semestinya ada akaun ISW — staff ISW boleh timpa manual ke Collector/
  Closer sebenar bila perlu di kob-list.html/kob-detail.html.
- `contact_id` — opsyenal. ID dalaman contact GHL (`{{contact.id}}`) —
  disimpan sbg **teks** ke `psy_patients.ghl_contact_id`, sekadar rujukan
  pantas/debug & future API call terus ke GHL. **TIDAK** dipakai utk
  padanan pesakit (kekal ikut telefon) — tiada kesan fungsi kalau tak
  dihantar.
- `status` (`{{contact.isw_status_2026}}`) — **SENGAJA TAK dihantar/tak
  diproses**. Field GHL ni ("ISW STATUS": SU KOB/SU KOB TBC/SU KOB A/EOB
  KIV/EOB TBP/EOB INVALID) sepatutnya boleh sync dua-hala dgn status sesi
  KOB kita, tapi buat masa ni **status appointment sentiasa "SU KOB"**
  (=Booked) sahaja — padan dgn default sedia ada (`status='booked'` bila
  appointment diterima). Sync dua-hala penuh (KIV/TBP/Pending Confirmation
  dll) **DITANGGUH** sbg kerja berasingan — `psy_kob_sessions.status` masih
  cuma `booked`/`hadir`/`completed`/`reschedule`/`cancelled` (5 nilai),
  belum sokong kategori GHL yang lain.
- `occupation` — opsyenal. GHL cuma ada **SATU** field gabungan
  `{{contact.kerja__syarikat}}` ("KERJA & SYARIKAT") utk pekerjaan+syarikat
  — dihantar terus ke `occupation` sepenuhnya (medan `company` kekal kosong
  drpd laluan GHL ni, boleh diisi manual di patients.html kalau perlu).
- `peranan_pendaftar` — opsyenal. GHL ada 4 kategori, disahkan maksud
  sebenar dgn user (25 Sept 2026):
  | Kategori GHL | Maksud | → `contact_preference` | → `registrant_capacity` |
  |---|---|---|---|
  | PESAKIT | Isi sendiri, dia lah pesakit | `pesakit` | `sendiri` |
  | WARIS BERTANGGUNGJAWAB | Urus semua, kuasa penuh | `waris` | `urus_penuh` |
  | WARIS WAKIL | Bantu je, kuasa terhad | `waris` | `bantu_isi` |
  | WARIS (biasa, tiada butiran) | Waris, tak spesifik sejauh mana | `waris` | *(tiada — lihat `borang_isi_sebagai`)* |

  Field ni jadi **sumber utama** kedua-dua `contact_preference` DAN
  `registrant_capacity` (kategorinya sendiri dah jawab "siapa" + "sejauh
  mana" sekali gus). Papar di kob-detail.html ("Maklumat Waris") &
  patient-hub.html (tab Profil). Turut **pra-pilih** soalan awal borang
  pendaftaran pesakit ("Anda mengisi borang ini sebagai...") supaya
  pesakit/waris tak ditanya 2 kali — lihat nota di `pendaftaran.html`.
- `borang_isi_sebagai` — opsyenal, **fallback sahaja**. Dipakai untuk isi
  `registrant_capacity` HANYA bila `peranan_pendaftar` tak beri butiran
  (cth kategori "WARIS" biasa) atau langsung tak dihantar. Dipermudah jadi
  kod pendek `sendiri`/`urus_penuh`/`bantu_isi` ikut label biasa; teks
  lain disimpan apa adanya kalau tak sepadan.
- `ic_number`/`date_of_birth`/`gender`/`marital_status`/`occupation`/
  `address`/`postcode`/`city`/`state`/`emergency_contact_*` —
  **semua opsyenal**, sama field yang dihantar di Workflow "Contact
  Changed" (c) di bawah — hantar sekali di sini kalau closer/telesales
  dah kumpul maklumat ni di GHL semasa booking, supaya borang
  pendaftaran ISW (`pendaftaran.html`) pra-isi terus. **PRA-ISI SAHAJA**
  (isi field kosong je, tak timpa data sedia ada) — pesakit tetap kena
  semak & submit sendiri. Buang mana-mana field yang GHL anda tiada, JANGAN
  hantar merge tag kosong/tak wujud (GHL akan hantar string literal
  `"{{...}}"` kalau tag tu salah/tiada nilai).

### b) Workflow "Order Submitted" (BAHARU)
- **Trigger:** *Order Submitted* / *Invoice Paid* (ikut mana tersedia di
  akaun anda), filter produk/pipeline yuran KOB
- **Action:** Webhook, URL & secret **sama** macam (a), body:
```json
{
  "event": "order",
  "phone": "{{contact.phone}}",
  "full_name": "{{contact.last_name}}",
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
  "full_name": "{{contact.last_name}}",
  "kob_code": "{{contact.first_name}}",
  "email": "{{contact.email}}",
  "ic_number": "{{contact.no_ic}}",
  "date_of_birth": "{{contact.date_of_birth}}",
  "gender": "{{contact.gender}}",
  "marital_status": "{{contact.status_perkahwinan}}",
  "occupation": "{{contact.kerja__syarikat}}",
  "address": "{{contact.address1}}",
  "postcode": "{{contact.postal_code}}",
  "city": "{{contact.city}}",
  "state": "{{contact.state}}",
  "emergency_contact_name": "{{contact.nama_waris_penjaga}}",
  "emergency_contact_phone": "{{contact.no_telefon_waris_penjaga}}",
  "emergency_contact_relationship": "{{contact.hubungan_waris_pesakit}}",
  "emergency_contact_email": "{{contact.email_waris_penjaga}}",
  "peranan_pendaftar": "{{contact.peranan_pendaftar}}",
  "borang_isi_sebagai": "{{contact.anda_mengisi_borang_ini_sebagai}}",
  "contact_id": "{{contact.id}}"
}
```
- Kemaskini pesakit **HANYA kalau field tempatan kosong** — tak timpa
  data yang pesakit/staff dah sahkan (borang pendaftaran/KYC ialah
  sumber kebenaran lebih tinggi selepas dihantar).
- **Semua field custom di atas (selain phone/full_name/email) OPSYENAL**
  — sama senarai dgn Workflow "Appointment" (a) di atas (rujuk situ untuk
  penjelasan `gender`/`occupation`). Merge tag di atas dah disahkan padan
  akaun GHL ISW sebenar — kalau akaun anda beza, semak Settings → Custom
  Fields. Field yang tak dihantar/tiada nilai akan diabaikan (bukan
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
`booked_by`/`owner_name` (jika dihantar) disimpan terus ke `closer_name`/
`collector_name` (teks, `closer_id`/`collector_id` kekal kosong — bukan
akaun staff ISW).

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
