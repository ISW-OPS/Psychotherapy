# ghl-pull-sync — Pull berkala GHL → ISW (ganti Workflow/webhook)

Panggil TERUS API GHL setiap 15 minit (cron) untuk tarik contact +
appointment + payment KOB masuk ISW. Menggantikan pendekatan 3 GHL
Workflow (Appointment/Order/Contact → `ghl-booking-webhook`) yang
bermasalah (merge field GHL Workflow format tak konsisten, "Test
workflow" tak simulasi konteks appointment sebenar). Data di sini datang
terus dari JSON API GHL — tiada isu merge-tag/format teks lagi.

```
pg_cron (setiap 15 min)
   └─► ghl-pull-sync ──► GET /contacts/ (800/run, SAMBUNG dari cursor psy_settings)
              (x-cron-secret)   └─► untuk contact ISW STATUS bermula KOB/SU KOB/SU OB/OB:
                                       ├─► GET /contacts/:id/appointments (tapis kalendar KOB)
                                       ├─► GET /payments/transactions?contactId= (tapis succeeded/paid/completed)
                                       └─► kalau DUA-DUA ada → psy_patients + psy_kob_sessions + psy_payments
                                           (kalau TAK → skip, tak dicipta)
```

**Akaun GHL disahkan >2000 contact** (anggaran awal <500 SALAH — jangan
percaya semula tanpa uji). Cuba scan penuh (5000/run sekaligus) →
**timeout** Edge Function (`WORKER_RESOURCE_LIMIT`, ~2.5 min). Reka
bentuk akhir: **checkpoint/cursor** — setiap run proses 800 contact
(8 muka surat), simpan kedudukan terakhir dalam `psy_settings`
(key `ghl_pull_sync_cursor`, jadual sedia ada, **tiada migration DB**),
run seterusnya sambung dari situ. Bila sampai hujung senarai, cursor
reset — pusingan baharu bermula. Merentas beberapa run (~15 min sekali),
seluruh akaun akhirnya discan secara berperingkat & berterusan
(self-healing — tangkap perubahan status lama juga, bukan sekadar
sekali sahaja).

**3 GHL Workflow yang sedang/pernah dibina (Appointment/Order/Contact)
TIDAK DIPERLUKAN LAGI** — boleh dibuang atau tinggalkan sebagai Draft di
GHL dashboard, tak digunakan oleh seni bina ni.

---

## 1. Custom field IDs — DISAHKAN (10 Ogos 2026)

**PENTING:** `GET /contacts/` pulangkan `customFields` sebagai
`{id, value}` SAHAJA — **TIADA `key`/`name` langsung**. ID field
STABIL merentas semua contact, tapi perlu disahkan dulu. Cara PALING
SENANG (bukan cross-reference contact demi contact) — panggil:

```bash
curl -s -X POST "https://<PROJECT_REF>.supabase.co/functions/v1/ghl-pull-sync" \
  -H "x-cron-secret: <GHL_PULL_CRON_SECRET>" -H "Content-Type: application/json" \
  -d '{"debug":true,"action":"list_custom_fields"}'
```
(Panggil `GET /locations/{locationId}/customFields` — pulangkan
`id`+`fieldKey`+`name` SEKALI untuk semua ~358 custom field akaun ni.
Cari field berdasarkan `name`/`fieldKey`, salin `id`.)

**Field GHL yang disahkan & digunakan** (`index.ts`, konstan `*_FIELD_ID`)
→ **kolum ISW** yang menerimanya:

| Konstan (`index.ts`) | ID GHL | fieldKey GHL | Nama paparan GHL | → Kolum `psy_patients` |
|---|---|---|---|---|
| `ISW_STATUS_FIELD_ID` | `TujlPbLGNn82yJpdr4Ff` | `contact.status` | ISW STATUS | *(tak disimpan — cuma tapis relevan, lihat §Filter di bawah)* |
| — (`c.phone`, field standard) | — | — | Phone | `phone` |
| — (`c.firstNameRaw`+`c.lastNameRaw`) | — | — | First/Last Name | `full_name` (**ASAL, TAK dibersihkan** — keputusan 10 Ogos, staff edit sendiri kalau perlu) |
| — (`c.email`, field standard) | — | — | Email | `email` |
| `IC_NUMBER_FIELD_ID` | `vXw0rgtYQEvfxoMY2AjV` | `contact.no_ic` | NO IC | `ic_number` |
| `HOME_ADDRESS_FIELD_ID` | `l2TcgLHVMKISHgf6R7ps` | `contact.alamat_rumah` | ALAMAT RUMAH | `address` (fallback `c.address1` kalau custom field kosong) |
| `WARIS_FIELD_ID` | `f1zSoMogQ9zW7xPmKYg3` | `contact.nama_penuh_waris__pesakit` | NAMA PENUH, NO. WARIS & EMAIL WARIS / PESAKIT | `emergency_contact_name` (teks bebas gabungan — TAK dipisah ke name/phone/email berasingan) |
| — (`GET /contacts/:id/appointments`) | — | — | (appointment terkini) | `psy_kob_sessions.scheduled_at` |
| — (`GET /payments/orders`) | — | — | (order paid/completed) | `psy_payments.total`+`ghl_transaction_id` |

**Tiada field tarikh lahir** dalam akaun GHL ni (`gender`/`date_of_birth`
TIDAK disync — GHL tak kumpul).

**Semua field kontak isi KOSONG SAHAJA** (`syncContactToPatient` dalam
`_shared/ghl-sync.ts`) — tak timpa data yang pesakit/staff dah sahkan.

### Filter — siapa yang disync

ISW STATUS mesti **bermula** dengan `KOB`, `SU KOB`, `SU OB`, atau `OB `
(peringkat konsultasi + pakej). **Dikecualikan** walaupun prefix padan:
`EOB*` (lead telesale, ~80% akaun), `KOB CANCEL`, `KOB NO SHOW`, dan
apa-apa mengandungi `KIV` (Kept In View — belum pasti, bukan patient
sebenar). Lihat `isKobRelevantStatus()`/`EXCLUDED_STATUS_EXACT` dalam
`index.ts`.

**Syarat masuk tambahan (keputusan user 11 Ogos 2026):** status ISW
STATUS relevan **sahaja TAK MEMADAI**. Contact mesti JUGA ada:

1. Sekurang-kurangnya **1 appointment pada salah satu kalendar KOB**
   (bukan mana-mana kalendar — `getKobCalendarIds()`/`isKobCalendarName()`
   auto-resolve ikut nama kalendar GHL, bukan ID hardcode). **Disahkan
   user 11 Ogos 2026** (`list_calendars` sebenar, akaun ada 54 kalendar
   keseluruhan) — **10** padan "KONSULTASI OVERHAUL BODY", tapi hanya
   **6** yang dimahukan (kalendar tapak `[WC1]`..`[WC5]`+`[EG]`); 4 lagi
   ("KOB VIP"/"VIP 2/3/4") **dikecualikan** atas keputusan user. Padanan
   2 lapis dlm kod: `KOB_CALENDAR_NAME_MATCH = 'KONSULTASI OVERHAUL BODY'`
   DAN NOT `KOB_CALENDAR_NAME_EXCLUDE = 'VIP'`.
2. Sekurang-kurangnya **1 GHL Transaction untuk PRODUK KOB KHUSUS**
   berstatus paid/completed/succeeded — guna `GET /payments/transactions`
   (**bukan** `/payments/orders` sahaja). **Disahkan 12 Ogos 2026**:
   kebanyakan yuran KOB akaun ni dibayar transfer manual, staff tandakan
   **Invoice** GHL "paid" (Text2Pay dll) — ini objek **berasingan** dari
   Order/checkout, TAK muncul dalam `/payments/orders` langsung.
   `/payments/transactions` ialah **ledger bersepadu rasmi GHL** —
   tangkap Order+Invoice+Stripe+Manual SEKALI GUS dalam status seragam
   (`succeeded`).
   **Tapisan KOB-sahaja (12 Ogos 2026):** mula-mula terima MANA-MANA
   transaction (pakej/kontrak lain termasuk) — kemudian keputusan user
   diketatkan kepada **yuran KOB sahaja**. `getKobPaidTransactions()`
   (`index.ts`): transaction order-sourced tapis ikut `entitySourceName`
   (cth "KOB GA WC1 260806"); transaction invoice-sourced (manual/
   Text2Pay, `entitySourceName` generik cth "Text2Pay - EOB 260808.")
   kena rujuk **invoice asal** (`name`/`invoiceItems[].name`, cth
   "KONSULTASI OVERHAUL BODY"), padan ikut `entityId`. Lihat
   `syncTransactionToPayment()` (`_shared/ghl-sync.ts`).

Contact yang lulus filter status tapi belum ada appointment KOB +
bayaran diskip sepenuhnya (`skippedNoPaymentOrBooking` dalam response)
— **TAK dicipta** dalam `psy_patients` lagi. Ni elak lead yang baru
ditukar status GHL (cth oleh telesale/closer) tapi belum benar-benar
book & bayar daripada muncul sebagai pesakit di ISW.

**WAJIB sebelum jadualkan cron** — sahkan nama kalendar KOB sebenar
padan carian "KOB":

```bash
curl -s -X POST ".../functions/v1/ghl-pull-sync" \
  -H "x-cron-secret: <GHL_PULL_CRON_SECRET>" -H "Content-Type: application/json" \
  -d '{"debug":true,"action":"list_calendars"}'
```

Semak `matchedKob` — patut pulangkan **6 kalendar** (WC1-WC5+EG, TAK
termasuk 4 "KOB VIP"). Kalau kosong/kurang/lebih dari 6, gate ni tak
betul — semak `KOB_CALENDAR_NAME_MATCH`/`KOB_CALENDAR_NAME_EXCLUDE`
dalam `index.ts` ikut nama sebenar dari `all` dalam response debug ni.

Kalau field GHL disusun semula/ID berubah di kemudian hari, panggil
`list_custom_fields` semula dan kemas kini konstan berkenaan dalam
`index.ts`.

---

## 2. Set secret + deploy

Guna semula `GHL_ISW_TOKEN`/`GHL_ISW_LOCATION_ID` sedia ada. **Satu
secret baharu diperlukan** — `GHL_PULL_CRON_SECRET` (tersendiri, BUKAN
timpa `CRON_SECRET` sedia ada, elak risiko pecahkan cron
`event-reminders` yang mungkin dah dijadualkan dgn nilai lama):

```bash
supabase secrets set GHL_PULL_CRON_SECRET="$(openssl rand -hex 24)"   # simpan untuk langkah 3 & 4
npx supabase functions deploy ghl-pull-sync --no-verify-jwt --project-ref ipmemyizigwgivccytcu
```

> `--no-verify-jwt` sebab pemanggil ialah cron (`x-cron-secret`), bukan JWT.

---

## 3. Uji manual (WAJIB sebelum jadualkan cron)

```bash
curl -s -X POST "https://ipmemyizigwgivccytcu.supabase.co/functions/v1/ghl-pull-sync" \
  -H "x-cron-secret: <GHL_PULL_CRON_SECRET>" -H "Content-Type: application/json"
```

Semak response — `totalContacts`, `kobRelevant`,
`skippedNoPaymentOrBooking`, `patientsSynced`, `appointmentsSynced`,
`paymentsSynced`, `errors`. Kalau `errors` banyak, JANGAN jadualkan cron
dulu — siasat punca (biasanya nama custom field atau bentuk response API
tak padan andaian). Kalau `skippedNoPaymentOrBooking` == `kobRelevant`
(semua diskip), besar kemungkinan `getKobCalendarIds()` tak jumpa
kalendar KOB — jalankan `list_calendars` (§Filter di atas) dulu.

Selepas berjaya, semak `patients.html`/`kob-list.html` — sahkan rekod
pesakit + tarikh appointment + bayaran masuk betul.

---

## 4. Jadualkan (pg_cron + pg_net)

```sql
select cron.schedule('ghl-pull-sync', '*/15 * * * *', $$
  select net.http_post(
    url     := 'https://<PROJECT_REF>.supabase.co/functions/v1/ghl-pull-sync',
    headers := jsonb_build_object('Content-Type','application/json','x-cron-secret','<GHL_PULL_CRON_SECRET>'),
    body    := '{}'::jsonb
  );
$$);
```

Tiada pg_cron? Guna cron luar (cth cron-job.org) hit URL sama setiap 15
minit dengan header `x-cron-secret`.

---

## Nota & had

- **Checkpoint/cursor** (psy_settings key `ghl_pull_sync_cursor`) —
  800 contact/run (`MAX_PAGES_PER_RUN=8` dalam `index.ts`). Kalau akaun
  terus berkembang & Edge Function mula timeout WALAUPUN dengan had ni,
  KURANGKAN `MAX_PAGES_PER_RUN` (bukan naikkan) — checkpoint bermakna
  lebih banyak run kecil selamat, TAK PERLU satu run besar.
- Response setiap run sertakan `reachedEnd`/`nextCursor` — semak
  `reachedEnd:true` sekali-sekala (tanda satu pusingan penuh siap) untuk
  anggarkan berapa lama liputan penuh mengambil masa pada akaun anda.
- Contact yang custom field ISW STATUS **tak** mengandungi "KOB" DISKIP
  sepenuhnya (elak cipta `psy_patients` untuk lead marketing rawak).
- Contact yang status LULUS tapi **tiada appointment kalendar KOB ATAU
  tiada order paid/completed** turut DISKIP (`skippedNoPaymentOrBooking`)
  — run seterusnya cuba lagi bila contact tu dah ada kedua-dua (cursor
  scan berulang secara berkala, self-healing).
- Semua logik sync (padan pesakit, isi field kosong sahaja, dedup
  bayaran ikut `ghl_transaction_id`) guna semula `_shared/ghl-sync.ts`
  — sama logik dgn `ghl-booking-webhook`/`ghl-initial-sync`, tiada
  duplikasi/drift.
- Appointment `mode` sentiasa default `f2f` (staff sahkan/betulkan
  manual dalam `kob-detail.html` — sama seperti keputusan sebelum ni).
- Log ringkasan setiap run ke `psy_audit_log`
  (`action='ghl_pull_sync.run'`) — semak di situ untuk jejak/debug.
