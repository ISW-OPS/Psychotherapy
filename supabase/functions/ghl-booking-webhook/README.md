# ghl-booking-webhook — Push booking + payment + contact (GHL → ISW)

> ⚠️ **GOTCHA KRITIKAL (disahkan 28 Okt 2026) — struktur payload GHL Webhook
> action:** Custom Data yang dikonfigurasi dalam action Webhook ("Custom
> Data" rows di Builder) **TIDAK** sampai di top-level JSON body. GHL
> bersarangkan SEMUANYA dalam satu objek `customData`
> (`payload.customData.bank_name`, BUKAN `payload.bank_name`). Top-level
> payload cuma "standard data" (field asli GHL seperti `phone`/`full_name`/
> `location`/`tags`/`user`/`workflow` — nilai/format kadang BEZA drpd
> versi `customData`, cth `phone` top-level `+60175655704` vs
> `customData.phone` `017-565 5704`). **Semua** pembacaan field dalam fail
> ni guna fungsi `pick()` (baca `customData` dulu, fallback top-level) —
> JANGAN baca `payload.xxx` terus bila tambah field baharu, guna `pick('xxx')`.

Bila closer/sales di GHL sahkan pesakit dah **bayar**, **tempah tarikh**
(KOB atau temujanji), atau **kemas kini maklumat**, GHL push maklumat tu
masuk ISW. Satu fungsi, tiga jenis event (`event` dalam body JSON):

| `event` | Bila dicetus | Apa yang berlaku di ISW |
|---|---|---|
| `appointment` (default — tiada field = ni) | Closer sahkan booking KOB | Padan/cipta pesakit + cipta/kemas kini `psy_kob_sessions` (`status='booked'`) |
| `order` | Closer sahkan bayaran yuran KOB | Padan/cipta pesakit + cipta rekod `psy_payments` (`payment_method='ghl'`) + `kob_status→'paid'` |
| `contact` | Maklumat pesakit dikemas kini di GHL | Padan/cipta pesakit sahaja (tiada sesi/bayaran disentuh) |
| `affiliate` | Orang daftar jadi affiliate/duta di funnel GHL (cth "Duta Sihat Sefitrahnya") | Padan/cipta **`psy_external_affiliates`** (BUKAN `psy_patients`) ikut phone — SELALU direkod (bukan pesakit ISW pun tetap direkod, supaya komisen pakej OB boleh dikira). Kalau phone padan pesakit sedia ada, `linked_patient_id` diisi + bank disync sekali ke `psy_patients` |

**Komisen pakej OB — model TIER (27 Okt 2026, keputusan user "kadar
komisen OB pun sama macam KOB"):** bila payload `appointment`/`contact`/
`order` bawa `referred_by_affiliate` (nama affiliate), fungsi cuba padan
nama tu dgn SATU rekod `psy_external_affiliates` sahaja (exact,
case-insensitive) — kalau jumpa, auto-cipta rekod `psy_referrals`
(`status='pending'`, `source='ghl_affiliate'`). Trigger
`trg_referral_qualify_on_payment` (27_affiliate.sql, **dikemaskini**)
"qualify" rekod tu jadi 1 **SU** bila DUA syarat dipenuhi: (1) pesakit tu
**settle sesi KOB** (`psy_kob_sessions.status IN ('hadir','completed')`)
DAN (2) **bayar pakej OB** (`psy_payments` completed, di ISW — GHL TIADA
visibiliti laluan bayaran ni). Kadar komisen kemudian ikut **tier volume
SU affiliate tu BULAN tu** (`psy_affiliate_commission_tiers` — 0-49
SU=RM20/SU, 50-99=RM30/SU, 100+=RM40/SU, dikira semula retroaktif setiap
kali SU baharu masuk), BUKAN fixed/percent per pakej macam rujukan
pesakit-ke-pesakit asal (`source='patient'`, `psy_affiliate_commission_rules`
— TIDAK terjejas). Bonus TAHUNAN (lepas 1,000+ SU setahun) **belum
dibina** — tangguh sehingga spec disahkan. Yuran KOB sendiri (GHL)
dikira terus di GHL Affiliate Manager (kalau produk ditanda
Commission-Eligible di campaign) — ISW tak sentuh bahagian tu. Lihat
bahagian "Menghubungkan (d) ↔ (a)/(c)" di bawah.

```
GHL Workflow (Appointment Status / Order Submitted / Contact Changed / Affiliate Registration)
   └─► Webhook action ──► ghl-booking-webhook ──► psy_patients          (padan/cipta ikut phone, event≠affiliate)
              (x-ghl-booking-secret)                ├─► psy_kob_sessions   (event=appointment)
                                                     ├─► psy_payments      (event=order, yuran KOB)
                                                     ├─► psy_external_affiliates (event=affiliate)
                                                     └─► psy_referrals     (auto, ikut referred_by_affiliate)
                                                            └─► trg_referral_qualify_on_payment
                                                                  (bila psy_payments pakej OB completed)
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
  "borang_isi_sebagai": "{{contact.anda_mengisi_borang_ini_sebagai}}",
  "referred_by_affiliate": "{{contact.referred_by_affiliate}}"
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
  **teks** ke `psy_kob_sessions.collector_name`, dipapar (read-only) di
  kolum **Collector**. Keputusan 28 Sept 2026: booked_by = ejen telesales
  yg collect/book lead masuk slot KOB, jadi tu Collector sebenar — gantikan
  `{{contact.collector_kob}}` lama (field GHL tu rupanya papar nama
  Kaunselor, bukan Collector — silap konfig, DIBUANG). (Alias diterima:
  `booked_by`/`bookedBy`.)
- `psy_kob_sessions.closer_name` TIDAK diisi drpd webhook ni langsung —
  Closer sentiasa dropdown manual di ISW (kob-list.html/kob-detail.html),
  sebab closer sebenar (yg tutup jualan pakej) cuma diketahui semasa sesi
  KOB berlangsung, bukan waktu booking.
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
- `referred_by_affiliate` — opsyenal. `{{contact.referred_by_affiliate}}`
  (custom field GHL, folder "PT Sytem" — **disahkan 27 Okt 2026**) — nama
  affiliate/duta yang rujuk PESAKIT ni (teks bebas, bukan ID). Disimpan ke
  `psy_patients.referred_by_affiliate_name` (isi kosong sahaja, papar
  read-only di kob-detail.html sbg "Dirujuk oleh Affiliate") **DAN**
  dipadan ke `psy_external_affiliates` utk **auto-cipta rekod komisen**
  (`psy_referrals`) — lihat bahagian "Menghubungkan (d) ↔ (a)/(c)" di
  bawah utk logik penuh. **Padanan ikut nama sahaja** (GHL tak bekalkan
  kod affiliate terus pada contact pesakit) — kalau 2 affiliate kongsi
  nama sama, tiada rekod komisen auto-dicipta (ambiguous), staff kena
  padan manual.

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
  "contact_id": "{{contact.id}}",
  "referred_by_affiliate": "{{contact.referred_by_affiliate}}"
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

### d) Workflow "Duta/Affiliate Registration" (BAHARU — GABUNG ke workflow
"01. Duta Registration" sedia ada, bukan workflow berasingan, keputusan
user 28 Okt 2026)

**Field key GHL disahkan 28 Okt 2026** (query key borang pendaftaran
"Duta Sihat Sefitrahnya" sebenar, disahkan user):

| Data | GHL field key |
|---|---|
| Nama affiliate | `{{contact.nama_agent}}` |
| Telefon affiliate | `{{contact.phone}}` |
| Email affiliate | `{{contact.email}}` |
| No IC affiliate | `{{contact.no_ic_agent}}` |
| Alamat affiliate | `{{contact.alamat_agent}}` |
| Nama bank | `{{contact.nama_bank}}` |
| No akaun bank | `{{contact.no_akaun_bank}}` |
| Pautan affiliate | `{{contact.affiliate_link}}` ⚠️ **TAK dikumpul borang** — diisi GHL SENDIRI (langkah "Add To Affiliate Manager"/"Add To Affiliate Campaign") SELEPAS submit, lihat nota Trigger di bawah |
| Kod rujukan KOB affiliate | `{{contact.kob_referal_code}}` ⚠️ **SATU "r"** — ejaan GHL sebenar, BUKAN "referral"; juga diisi SELEPAS submit (nota sticky GHL: "Create Coupon Code... Key in ke dalam Custom Field AFFILIATION") |

- **Trigger — PENTING, BUKAN "Form Submitted":** `affiliate_link`/
  `kob_referal_code` **belum wujud** sejurus borang dihantar (GHL
  Affiliate Manager/Campaign + coupon code baru digenerate SELEPAS tu,
  ikut langkah dalam workflow "01. Duta Registration" sedia ada —
  Assign to user → Add To Affiliate Manager → Add To Affiliate
  Campaign → cipta coupon/referral link → key in custom field). Letak
  action Webhook ni di **PENGHUJUNG** workflow "01. Duta Registration"
  sedia ada (lepas SEMUA langkah tu siap, bukan sejurus Form Submitted),
  **ATAU** kalau nak berasingan, guna trigger *Contact Changed* ditapis
  khusus `affiliate_link` berubah ke "ada nilai" — supaya payload bawa
  data LENGKAP, bukan medan kosong.
- **Action:** Webhook, URL & secret **sama**, body:
```json
{
  "pt_event": "affiliate",
  "phone": "{{contact.phone}}",
  "full_name": "{{contact.nama_agent}}",
  "email": "{{contact.email}}",
  "ic_number": "{{contact.no_ic_agent}}",
  "address": "{{contact.alamat_agent}}",
  "bank_name": "{{contact.nama_bank}}",
  "bank_account_no": "{{contact.no_akaun_bank}}",
  "bank_account_holder": "{{contact.nama_agent}}",
  "affiliate_link": "{{contact.affiliate_link}}",
  "kob_referal_code": "{{contact.kob_referal_code}}",
  "contact_id": "{{contact.id}}"
}
```
> ⚠️ **Guna key `pt_event`, BUKAN `event`** (disahkan 28 Okt 2026 — key
> `event` gagal dalam ujian sebenar, disyaki berlanggar dgn "standard
> data" GHL yang turut ada field `event` tersendiri). Fungsi terima
> kedua-dua (`pt_event` diutamakan, `event` kekal fallback) tapi `pt_event`
> yang DISAHKAN berfungsi — guna itu dalam Custom Data.

- **Entiti teras `psy_external_affiliates` (BUKAN `psy_patients`)** —
  orang yang daftar jadi affiliate/duta **tak semestinya pesakit ISW**.
  Fungsi `upsertExternalAffiliate()` padan ikut 9 digit terakhir `phone`:
  - **SELALU** cipta/kemas kini `psy_external_affiliates` (nama/email/
    bank/kod/link) — tiada "matchOnly", affiliate ni WAJIB direkod
    supaya komisen pakej OB boleh dikira kelak (lihat bahagian
    "Menghubungkan" di bawah).
  - **Kalau** phone padan pesakit ISW sedia ada → `linked_patient_id`
    diisi + bank/kod/link disync SEKALI ke `psy_patients` jua (fill-
    kosong-sahaja), supaya `affiliate.html`/`profile.html` terus boleh
    guna TANPA pesakit isi bank 2 kali. **Tiada pesakit BARU dicipta**
    kalau tiada padanan — itu kekal tingkah laku sama macam sebelum ni.
- Response: `{ success, event:'affiliate', affiliate_id, linked_patient_id }`.

### Menghubungkan (d) ↔ (a)/(c) — "siapa rujuk siapa" + komisen pakej OB

GHL Affiliate Manager **tertutup sepenuhnya** — tiada API awam, tiada
Workflow trigger khas, tiada merge tag standard utk attribution
(disahkan dgn AI GHL 27 Okt 2026). Satu-satunya jambatan yang GHL
sediakan ialah DUA custom field berasingan di atas (`referred_by_affiliate`
pada contact pesakit vs `nama_agent`/`kob_referal_code` pada contact
affiliate). Jadi di ISW (`attributeReferralToAffiliate()`,
`_shared/ghl-sync.ts`):
- Bila payload `appointment`/`contact`/`order` bawa `referred_by_affiliate`
  (nama), fungsi cari **SATU** rekod `psy_external_affiliates` padan nama
  (case-insensitive EXACT). Jumpa **tepat satu** → auto-cipta
  `psy_referrals` (`status='pending'`, `referrer_affiliate_id=...`,
  `source='ghl_affiliate'`). Tiada padanan ATAU >1 padanan (nama sama)
  → tiada rekod dicipta (senyap, tak gagalkan webhook) — staff kena
  padan manual di `affiliate.html` (belum ada UI utk ni, lihat nota).
  **Tak pernah timpa** rujukan sedia ada (UNIQUE `referee_patient_id`).
- Lepas rekod `psy_referrals` wujud, `trg_referral_qualify_on_payment`
  (27_affiliate.sql, **dikemaskini** — cawangan baharu khas
  `source='ghl_affiliate'`, logik `source='patient'` asal tak disentuh)
  "qualify" rekod tu jadi 1 SU bila pesakit settle KOB **DAN** bayar
  pakej OB (`psy_payments`, HitPay di ISW), lepas tu panggil
  `recalc_affiliate_commission_tier()` (kira semula tier bulan tu utk
  affiliate berkenaan, lihat `psy_affiliate_commission_tiers` di
  27_affiliate.sql). Payout kemudiannya diproses di `affiliate.html`
  macam rujukan pesakit-ke-pesakit biasa — bezanya cuma perujuk jadi
  `psy_external_affiliates` bukan `psy_patients` (`startPayout()` cipta
  `psy_affiliate_payouts.affiliate_id` bukan `.patient_id`).
- Kalau kelak GHL ada field kod affiliate pada contact PESAKIT juga
  (bukan setakat nama), tambah `affiliate_code` ke payload (a)/(c) &
  padan ikut kod (lebih tepat drpd nama) — **belum wujud lagi**, jangan
  andaikan ia dihantar.
- Field lain dalam folder GHL "PT Sytem" (`contact.pt_in_system`,
  `contact.isw_mrn`, `contact.isw_registration_status`) nampak macam
  dirancang untuk **ISW tulis BALIK ke GHL** (arah bertentangan drpd
  webhook ni) — **BELUM dibina**, rujuk `sync-ghl` (fungsi sedia ada,
  ISW→GHL) kalau nak sambungkan kelak.

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

**`event=appointment`/`order`/`contact`** mula dengan padan pesakit ikut 9
digit terakhir telefon (`phone`/`emergency_contact_phone`). Tiada padanan
→ cipta `psy_patients` baru: `status='pending_kyc'`, `kob_status='paid'`,
`referral_source='GHL'`, MRN auto-jana, `user_id IS NULL` (belum ada akaun
login). Kalau payload bawa `referred_by_affiliate`, cuba auto-cipta rekod
komisen `psy_referrals` lepas tu (lihat "Menghubungkan (d) ↔ (a)/(c)").

**`event=affiliate`** entiti teras **`psy_external_affiliates`** (BUKAN
`psy_patients`) — SELALU direkod (padan/cipta ikut phone), tiada "tiada
padanan → skip". `linked_patient_id` diisi (+ bank disync ke
`psy_patients`) kalau phone padan pesakit ISW sedia ada.

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
(guard sama macam di atas). Ni yuran KOB sahaja — komisen KOB (kalau ada)
dikira di GHL Affiliate Manager sendiri, bukan sini.

**`event=contact`** — padan/cipta pesakit sahaja, tiada sesi/bayaran.

Semua event log ke `psy_audit_log` (`action='ghl_booking.received'` /
`'ghl_order.received'` / `'ghl_contact.received'` / `'ghl_affiliate.received'` /
`'ghl_affiliate_attribution.created'`), best-effort (gagal log tak
gagalkan webhook).

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
