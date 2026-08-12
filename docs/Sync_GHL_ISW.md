# Sync GHL ⇄ ISW

Ringkasan integrasi sync data DUA HALA antara GoHighLevel (GHL) dan
ISW — dibina 10-11 Ogos 2026.

- **GHL → ISW** (tarik, cron 15 min): `ghl-pull-sync` — ganti pendekatan
  GHL Workflow/webhook yang bermasalah (merge field tak konsisten
  format, "Test workflow" tak simulasi konteks appointment sebenar).
- **ISW → GHL** (tolak, Database Webhook automatik): `sync-ghl` —
  push status pesakit ISW terus ke kad contact GHL, supaya closer
  nampak konteks tanpa buka ISW.

## GHL → ISW — Seni bina

```
pg_cron (setiap 15 min, belum dijadualkan lagi — masih manual)
   └─► ghl-pull-sync ──► GET /contacts/ (checkpoint/cursor, psy_settings)
              (x-cron-secret)   └─► untuk contact ISW STATUS relevan:
                                       ├─► GET /contacts/:id/appointments (tapis kalendar KOB)
                                       ├─► GET /payments/orders?contactId= (tapis paid/completed)
                                       └─► kalau DUA-DUA ada →
                                              psy_patients (padan/cipta ikut phone)
                                              + psy_kob_sessions + psy_payments
                                           (kalau tak → skip, cuba lagi run seterusnya)
```

Fungsi: `supabase/functions/ghl-pull-sync/index.ts` (README teknikal
penuh + cara re-derive field ID kalau berubah: `README.md` sebelah fail
ni). Kod teras sync (padan pesakit ikut telefon, isi field kosong
sahaja, dedup bayaran) dikongsi dengan `ghl-booking-webhook` (webhook
lama, tak digunakan lagi tapi kekal deployed) melalui
`supabase/functions/_shared/ghl-sync.ts`.

## Filter — siapa yang disync

ISW STATUS (custom field GHL) mesti **bermula** dengan `KOB`, `SU KOB`,
`SU OB`, atau `OB `.

**Dikecualikan** walaupun prefix padan:
- `EOB*` — lead telesale (~80% akaun GHL), belum jadi patient KOB
- `KOB CANCEL` — dibatalkan
- `KOB NO SHOW` — tak hadir
- Apa-apa mengandungi `KIV` (Kept In View) — belum pasti, bukan patient sebenar

**Syarat masuk tambahan (11 Ogos 2026):** status relevan sahaja TAK
MEMADAI — contact mesti JUGA ada (a) sekurang-kurangnya 1 appointment
pada salah satu **6 kalendar KOB tapak** (`KONSULTASI OVERHAUL BODY
[WC1]` hingga `[WC5]` + `[EG]`) DAN (b) sekurang-kurangnya 1 **order
paid/completed**. Akaun sebenarnya ada 10 kalendar mengandungi
"KONSULTASI OVERHAUL BODY" (54 kalendar keseluruhan) — 4 daripadanya
("KOB VIP"/"VIP 2/3/4") **sengaja dikecualikan** (keputusan user, bukan
slot tapak biasa). Padanan kod: `isKobCalendarName()` — includes nama
DAN NOT includes "VIP". Belum ada kedua-dua syarat → diskip, TAK
dicipta dalam `psy_patients` lagi (cuba lagi run seterusnya). Lihat
§Filter dalam `README.md` sebelah `ghl-pull-sync/index.ts` untuk cara
sahkan nama kalendar (`{debug:true,action:'list_calendars'}`).

## Data yang ditarik

| GHL field | fieldKey GHL | → Kolum `psy_patients` |
|---|---|---|
| ISW STATUS | `contact.status` | *(filter sahaja, tak disimpan)* |
| Phone | standard | `phone` |
| First/Last Name | standard | `full_name` — **nama ASAL, TAK dibersihkan** (termasuk prefix kod booking cth "KOB'26-00090. Hjh Azah"; staff edit sendiri kalau perlu) |
| Email | standard | `email` |
| NO IC | `contact.no_ic` | `ic_number` |
| ALAMAT RUMAH | `contact.alamat_rumah` | `address` |
| NAMA PENUH, NO. WARIS & EMAIL WARIS/PESAKIT | `contact.nama_penuh_waris__pesakit` | `emergency_contact_name` (teks bebas gabungan — TAK dipisah ke name/phone/email berasingan) |
| Appointment terkini | (`GET /contacts/:id/appointments`) | `psy_kob_sessions.scheduled_at` |
| Order paid/completed | (`GET /payments/orders`) | `psy_payments.total` + `ghl_transaction_id` |

**Tiada field tarikh lahir/gender** — GHL tak kumpul untuk akaun ni.

**Peraturan keselamatan:** semua field kontak isi **KOSONG SAHAJA**
(`syncContactToPatient`, `_shared/ghl-sync.ts`) — tak pernah timpa data
yang pesakit/staff dah sahkan (contoh lepas isi borang pendaftaran).

## ISW → GHL — `supabase/functions/sync-ghl/index.ts`

Database Webhook Supabase (Dashboard → Integrations → Database
Webhooks — **2 hook dipasang 11 Ogos**: `sync_ghl_patients` atas
`psy_patients` INSERT/UPDATE, `sync_ghl_kob_sessions` atas
`psy_kob_sessions` INSERT/UPDATE) memanggil `sync-ghl` bila kob_status
ATAU status pendaftaran pesakit berubah.

Upsert contact GHL ikut telefon, isi **8 custom field** (nama papar
"Isw" ditukar ke **"PT"** 12 Ogos — `fieldKey` kekal `isw_*`, tiada
perubahan kod):

| Kolum ISW | → Custom field GHL |
|---|---|
| `kob_status` (+ label mesra-closer) | Kob Stage (`contact.kob_stage`) |
| `kob_status` (nilai mentah) | Kob Status Raw (`contact.kob_status_raw`) |
| `active_package_name` | Kob Package (`contact.kob_package`) |
| `package_expires_at` | Kob Package Expires (`contact.kob_package_expires`) |
| `mrn` | **PT Mrn** (`contact.isw_mrn`) |
| `psy_kob_sessions` (tarikh+mod) | Kob Session Date (`contact.kob_session_date`) |
| `status` (pending_kyc/active/dll) | **PT Registration Status** (`contact.isw_registration_status`) — "pesakit dah signup ke belum" |
| *(tetap)* | **PT In System** (`contact.pt_in_system`) — sentiasa `Yes`, jawab "rekod ISW wujud ke tak" (lihat nota) |

`PT Registration Status` = binari mudah untuk automation GHL:
**`Active`** hanya bila `status='active'` (dah hantar borang
pendaftaran); **`Not Active`** untuk semua status lain (pending_kyc/
unregistered/inactive/archived/deceased/rejected/deleted). Logik:
`registrationLabel()` dalam `index.ts`.

`PT In System` sentiasa `Yes` bila terisi — sebab `sync-ghl` cuma jalan
bila rekod `psy_patients` MEMANG wujud (webhook dicetus oleh
perubahan pada rekod tu). **Field ni KOSONG di GHL = ISW tak pernah
ada rekod pesakit tu langsung** (belum sync dari GHL, belum daftar
sendiri). Beza dari `PT Registration Status` yang jawab soalan LEBIH
halus (dah daftar/aktif atau baru wujud tapi belum daftar).

Tag dilekatkan: `patient`, `isw-kob`, `kob:<status>`.

**Dilangkau sengaja:** Opportunity/pipeline stage — tiada pipeline GHL
padan 8 peringkat `kob_status` ISW wujud dalam akaun ini (disahkan via
`list_pipelines`, banyak pipeline kempen lain tapi tiada yang sepadan).

Semua 7 custom field dicipta terus via API (`create_custom_field`
action, `ghl-pull-sync`) — nama field ditaip supaya `fieldKey`
auto-terbit **tepat** padan `CF` dalam `sync-ghl/index.ts` (cth nama
"Kob Stage" → fieldKey `contact.kob_stage`).

## UI — `roles/staff/patients.html`

- Lajur **"Sumber"** — chip `GHL` (navy) atau `ISW` (kelabu), ikut
  `referral_source`. **Kekal rekod asal-usul selama-lamanya** — TAK
  ditukar automatik walaupun pesakit dah daftar sendiri/staff dah
  uruskan (supaya tracking konversi funnel GHL→ISW kekal boleh dibuat).
- Lajur **"Status"** & **"Outcome"** berasingan — `Status` = keadaan
  akaun (Active/Pending Pendaftaran/dll), `Outcome` = keadaan rawatan
  (In Progress/Completed/Discontinued/Deceased). Gabungan Sumber+Status
  cukup untuk bezakan "lead mentah dari sync" vs "pesakit yang dah
  disahkan/aktif".
- **Klik chip "GHL"** → staff sahkan pesakit tu (confirm dialog) →
  `status` bertukar ke `active` (`referral_source` KEKAL, tak berubah)
  — keluar dari "Pending Pendaftaran", masuk senarai "All". Fungsi:
  `confirmSourceIsw()`.
- Filter **"Semua Sumber"** (GHL/ISW) + **"Semua Status"** (lengkap 8
  nilai status + 4 outcome) ditambah sekali dengan kerja ni.
- Realtime — senarai auto-refresh (`subscribeListRealtime()`,
  `postgres_changes` atas `psy_patients`) bila sync jalan di latar
  belakang, tak perlu refresh manual.

## Kalendar & Jadual — `roles/staff/appointments.html`

KOB (gabungan GHL+ISW, dari `psy_kob_sessions`) kini muncul terus dalam
calendar staff ni sebagai chip 🩺 — dulu langsung tak dipaparkan (page
ni asalnya untuk Pelan Rawatan Mingguan sahaja). Panel filter "☰ Papar"
(gaya GHL "Manage view") ditambah — checkbox Sesi Rawatan/Peristiwa/
Lawatan/Cuti/KOB, + filter coach turut kesan KOB.

## Status semasa (11 Ogos 2026)

**GHL → ISW (`ghl-pull-sync`):**
- ✅ Fungsi dibina, dideploy ke **testing** (`ipmemyizigwgivccytcu`) sahaja
- ✅ Diuji end-to-end (contact, appointment, payment, IC/alamat/waris)
- ✅ Cleanup sekali sahaja: 698 pesakit (CANCEL/NO SHOW/KIV) di-soft-delete
- ✅ 662 nama dipulihkan ke bentuk asal GHL (lepas keputusan "jangan bersih nama")
- ⚠️ **BAHARU (11 Ogos, belum deploy/diuji):** syarat masuk ditambah —
  mesti ada appointment pada salah satu 6 kalendar KOB (WC1-WC5+EG) +
  order paid/completed, bukan status sahaja. Nama kalendar sebenar
  **disahkan** oleh user (screenshot GHL) — `KONSULTASI OVERHAUL BODY
  [WC1..5]`/`[EG]`, grup "KOB [WC]". **Seterusnya:** deploy semula +
  jalankan `{debug:true,action:'list_calendars'}` (sahkan `matchedKob`
  = 6) dulu sebelum uji manual penuh (lihat §Filter, `README.md`)
- ⏳ **Belum dijadualkan sebagai cron** — masih dipanggil manual (curl)

**ISW → GHL (`sync-ghl`):**
- ✅ 7 custom field GHL dicipta (kob_stage, kob_status_raw, kob_package,
  kob_package_expires, isw_mrn, kob_session_date, isw_registration_status)
- ✅ Fungsi dideploy ke **testing**, diuji manual (push custom field
  disahkan betul terpapar di kad contact GHL sebenar)
- ✅ **2 Database Webhook dipasang** (`sync_ghl_patients` atas
  `psy_patients`, `sync_ghl_kob_sessions` atas `psy_kob_sessions`) —
  push kini **automatik**, tak perlu panggil manual lagi
- ⏳ Opportunity/pipeline stage TAK diaktifkan (tiada pipeline GHL padan)

**Kedua-dua arah:**
- ⏳ **Belum deploy ke production** — semua kerja ni testing sahaja,
  perlu keputusan berasingan + akaun CLI berbeza (`isw.creatives1@gmail.com`)
  untuk deploy production
- ⏳ **Backfill `sync-ghl` untuk rekod sedia ada** (keputusan user 12
  Ogos: tangguh sehingga masa deploy production) — `sync-ghl` hanya
  push bila `psy_patients` UPDATE/INSERT tercetus SELEPAS webhook
  dipasang, jadi pesakit sedia ada (kob_status/status tak berubah lagi
  sejak tu) akan ada field PT KOSONG di GHL sehingga: (a) status mereka
  genuine berubah, ATAU (b) backfill sekali dijalankan (loop semua
  `psy_patients` berfoto, panggil `sync-ghl` untuk setiap satu).

## Nota sejarah (kenapa bukan webhook)

Cubaan awal guna 3 GHL Workflow (Appointment/Order/Contact → webhook
`ghl-booking-webhook`) menemui banyak halangan: merge field GHL format
tak konsisten (masa "1530" tanpa titik dua, custom field ID tanpa
key/name), dan "Test workflow" GHL didapati tak simulasi konteks
appointment sebenar (sentiasa gagal walaupun konfigurasi betul). Fungsi
`ghl-booking-webhook` kekal deployed (harmless) tapi digantikan
sepenuhnya oleh pendekatan pull (`ghl-pull-sync`) — data terus dari
JSON API, tiada isu merge-tag.
