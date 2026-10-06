# Dokumen Projek ISW (digabung)

Gabungan dokumen perancangan dan spesifikasi. Setiap bahagian kekal seperti asal, dengan nama fail asal sebagai tajuk. Rujukan silang antara bahagian mungkin tak lagi tepat selepas gabungan.

---



# ===== extra/Meeting_Izzah_Soalan_Risk_Kepatuhan.md =====

# Soalan Meeting Izzah — Modul Risk Alert & Kepatuhan

**Tujuan**: Tentukan definisi & kriteria untuk dua modul yang sedang **greyed-out** sehingga keputusan diambil:
1. **Risk Alert** ("Pesakit Perlu Tindakan Segera" dalam Dashboard Coach)
2. **Kepatuhan** ([kepatuhan.html](../roles/staff/kepatuhan.html), kad "Check-in 7 Hari" dalam Dashboard, column "Status Kepatuhan" dalam table pesakit)

---

## A. Konsep Asas

1. **Apakah "risk"** dalam konteks Ibnu Sina Wellness?
   - Risiko klinikal (BP tinggi, gula tinggi, simptom bahaya)?
   - Risiko keciciran rawatan (patient drop-out)?
   - Risiko ketidakpatuhan (tak ambil madu, tak buat protokol)?
   - Risiko emotional/mental (mood rendah, stress)?
   - Gabungan kesemuanya?

2. **Siapa yang patut bertindak** bila ada risk alert?
   - Coach pesakit terus?
   - Doktor untuk semakan klinikal?
   - Manager untuk escalation?
   - Semua sekali (berbeza ikut jenis risk)?

3. **Bila risk dianggap "Segera"** vs boleh tangguh?
   - Tempoh tindak balas: dalam berapa jam/hari?
   - Adakah ada SLA berbeza untuk severity berbeza?

---

## B. Kriteria & Severity

4. **Severity level** — adakah perlu 4 tingkat (`low / medium / high / critical`) seperti dalam schema?
   - Atau cukup 2 tingkat (Amaran / Kritis) sahaja?
   - Atau 3 (Info / Amaran / Kritis)?

5. **Threshold untuk setiap severity** — boleh izzah definisikan?

   Contoh rangka soalan (bukan cadangan):
   - **Kritis**: bila apa berlaku? (cth: BP > 180/110? Tiada check-in 7 hari? Tiada hadir 2 sesi berturut?)
   - **Amaran**: bila apa berlaku? (cth: BP > 160/100? Tiada check-in 3 hari? Mood < 3/10?)
   - **Info**: hanya untuk maklumat sahaja?

6. **Multi-signal triggers** — adakah satu signal cukup, atau perlu gabungan?
   - Contoh: BP tinggi SAHAJA = amaran, atau BP tinggi + mood rendah baru kritis?

---

## C. Source Data

7. **Data apa yang Izzah anggap relevan untuk pantau?** Pilih dari yang sistem dah rekod:

   | Data | Rekod harian/mingguan? | Boleh jadi signal? |
   |---|---|---|
   | Daily check-in (mood, energy, sleep, simptom) | Harian | Ya/Tidak? |
   | Kepatuhan protokol (madu, nafas, terapi bumi, kelapa, kolon, berjemur, pantang) | Mingguan | Ya/Tidak? |
   | Vital signs (BP, HR, BMI, berat) | Mingguan/setiap sesi | Ya/Tidak? |
   | Status sesi (hadir/cancel/no-show) | Mingguan | Ya/Tidak? |
   | Feedback pesakit (rating + komen) | Mingguan | Ya/Tidak? |
   | Skor BPS-S (bio/psycho/social/spiritual goals) | Mingguan | Ya/Tidak? |

8. **Adakah ada data luar yang perlu**, yang sistem belum rekod?
   - HbA1c, lipid profile, lab results?
   - Soalan PHQ-9 / GAD-7 (mental health screening)?
   - Lain-lain?

---

## D. Workflow

9. **Auto vs Manual** — bila alert wujud:
   - **Auto** (sistem kira dari data → cipta alert sendiri)?
   - **Manual** (coach/doktor flag pesakit sebagai berisiko)?
   - **Gabungan** (auto detect + boleh manual tambah)?

10. **Apabila ada alert**, apa coach perlu buat?
    - Acknowledge (tandakan dah baca) — sudah ada
    - Resolve (tandakan sudah diatasi) — sudah ada
    - Eskalasi ke doktor — perlu ke?
    - Catat tindakan yang diambil — perlu ke?

11. **Notifikasi** — perlu hantar ke mana?
    - In-app notification untuk coach?
    - WhatsApp/SMS untuk coach kalau Kritis?
    - Email harian summary?

12. **Lifecycle alert**:
    - Bila alert auto-resolve? (cth: patient check-in semula → alert "tiada check-in" hilang sendiri?)
    - Atau coach kena manually resolve setiap alert?

---

## E. Pemaparan UI

13. **Dashboard Coach** — sekarang panel tunjuk top 3. Berapa banyak Izzah nak nampak?

14. **Patient Hub** — bila buka pesakit individu, perlu tunjuk semua sejarah alert dia?

15. **Risk report** — perlu ada page khas untuk senarai semua alert (sudah ada `risk.html`)?

---

## F. Prioriti & Skop Sprint

16. Adakah modul Risk Alert ini **prioriti sprint terdekat**, atau boleh tangguh ke kemudian?

17. Kalau prioriti — bermula dari rule yang **paling mudah/jelas dulu** (cth: tiada check-in X hari)?

18. Adakah Izzah ada **contoh dari klinik lain** atau standard amalan psychotherapy yang patut dirujuk?

---

---

## G. Modul Kepatuhan

19. **Berapa jenis kepatuhan** yang ISW pantau? Yang saya nampak dari mockup awal:
    - **Kategori OB**: Pesakit A (Disiplin & Patuh 100%) / Pesakit B (Separuh Patuh — tak jaga pantang makan) / Pesakit C (Tidak patuh)
    - Adakah klasifikasi ini formal? Atau hanya rujukan dalaman?

20. **Kepatuhan dikira berdasarkan apa?** Jujur, sekarang ada DUA tafsiran berbeza dalam sistem yang konflik:
    - **Session-based**: % sesi hadir vs total sesi (cara `kepatuhan.html` kira sekarang)
    - **Check-in based**: % hari pesakit check-in vs 7 hari (cara dashboard kira)
    - **Protokol-based**: % protokol diikut (madu, nafas, terapi bumi, kelapa, kolon, berjemur, pantang)
    - **Gabungan**: weighted score dari semua di atas
    - **Manual categorization**: coach/doktor flag pesakit ikut kategori OB (A/B/C) selepas review

    **Mana satu yang betul untuk ISW?** Atau perlu ada beberapa metric berasingan?

21. **Kalau guna kategori OB (A/B/C)** — siapa yang assign kategori ni?
    - Coach selepas observation?
    - Auto dari data?
    - Doktor selepas semakan?
    - Pesakit sendiri (self-assessment)?

22. **Threshold "patuh" vs "tidak patuh"** — kalau guna metric automatik, apa cut-off?
    - Patuh 100%: macam mana ditakrifkan? Semua check-in 7/7? Semua sesi hadir? Semua protokol komplit?
    - Separuh Patuh: berapa peratus? 50-79%? Bergantung pada apa?
    - Tidak Patuh: di bawah berapa peratus?

23. **Period pengiraan** — kepatuhan dikira untuk:
    - Mingguan? Bulanan? Selama tempoh rawatan keseluruhan?
    - Adakah ada "rolling 7 days" atau snapshot pada masa tertentu?

24. **Pantang makanan** — disebut dalam kategori OB sebagai signal penting. Sekarang sistem rekod sebagai boolean (Ya/Tidak) sekali seminggu dalam `psy_plan_compliance.pantang`. Cukup ke, atau perlu lebih detail (jenis makanan dilanggar)?

25. **Bagaimana kepatuhan dipaparkan**?
    - Pada coach: per-pesakit dengan status A/B/C, atau % skor?
    - Pada doktor: ringkasan agregat untuk semua pesakit dia review?
    - Pada manager: trend mingguan/bulanan untuk seluruh klinik?

---

## Maklumat untuk dibawa ke meeting

### Risk Alert
- Schema `psy_risk_alerts` sudah wujud dengan column `severity` (low/medium/high/critical), `category`, `description`, `status` (open/acknowledged/resolved).
- Page [risk.html](../roles/staff/risk.html) sudah boleh paparkan dan acknowledge alert — tinggal logik untuk **cipta** alert sahaja yang belum.
- Panel "Pesakit Perlu Tindakan Segera" dalam Dashboard Coach diset "Akan Datang".

### Kepatuhan
- [kepatuhan.html](../roles/staff/kepatuhan.html) — keseluruhan page di-greyed-out dengan placeholder "Modul Kepatuhan Sedang Disediakan".
- Kad "Check-in 7 Hari" dalam Dashboard Coach — kekal aktif, tapi nama dah ditukar dari "Kepatuhan" supaya jelas ia khas untuk check-in harian sahaja (bukan kepatuhan keseluruhan).
- Column "Status Kepatuhan" dalam table "Pesakit Saya" Dashboard Coach — diset "Menunggu kriteria".
- Panel "Trend Kepatuhan" dalam Dashboard Coach — greyed-out.

### Data yang sistem dah ada untuk kira kepatuhan
- `psy_daily_checkins`: mood, energy, sleep, simptom (harian)
- `psy_plan_compliance`: madu_sudu, nafas_kali, bumi_minit, kelapa_kali, kolon_kali, berjemur (bool), pantang (bool) — mingguan
- `psy_plan_weekly_progress`: status sesi (hadir/cancel/reschedule) — mingguan
- `psy_vitals`: BP, HR, BMI — setiap sesi
- `psy_weekly_feedback`: rating + komen — mingguan

**Tarikh meeting**: 26 Mei 2026


---


# ===== extra/PENDING_TASKS.md =====

# ISW — Senarai Pending Tasks

Status setakat: 24 Mei 2026

---

## 🔴 Pending — Menunggu Keputusan Domain (Meeting Izzah 26 Mei)

### 1. Risk Alert
- **Status**: Panel "Pesakit Perlu Tindakan Segera" di Dashboard Coach **greyed-out**
- **Issue**: Schema `psy_risk_alerts` wujud tapi **tiada logik INSERT** dari mana-mana tempat. Severity (low/medium/high/critical) tiada makna sebenar.
- **Tunggu**: Definisi "risk" + threshold severity + auto-trigger rules dari Izzah
- **Ref**: [Meeting_Izzah_Soalan_Risk_Kepatuhan.md](Meeting_Izzah_Soalan_Risk_Kepatuhan.md) Bahagian A–F

### 2. Kepatuhan
- **Status**: [kepatuhan.html](../roles/staff/kepatuhan.html) **keseluruhan page greyed-out**. Kad Dashboard Coach tukar dari "Kepatuhan 7 Hari" → "Check-in 7 Hari" (lebih jelas)
- **Issue**: 3 definisi konflik: session-based vs check-in based vs kategori OB (A/B/C)
- **Tunggu**: Pilihan definisi + threshold + siapa assign kategori
- **Ref**: [Meeting_Izzah_Soalan_Risk_Kepatuhan.md](Meeting_Izzah_Soalan_Risk_Kepatuhan.md) Bahagian G

---

## 🟡 Pending — Feature Belum Implement (Tiada Backend)

### 3. Quick Actions Dashboard Coach
- **Greyed-out**: 4 butang (💬 Mesej, 📞 Call, 📋 Checklist, 📁 Rekod)
- **Issue**: Sistem tiada messaging/VOIP. Mesej & Call tak boleh connect ke mana-mana.
- **Cadangan**: Implement WhatsApp link (`https://wa.me/...`) + tel link, atau buang sahaja

### 4. Sesi 1:1 Hakeema
- **Greyed-out**: Panel dalam Dashboard Coach
- **Issue**: Modul Hakeema belum ada langsung (tiada schema, tiada flow)

### 5. Reaksi Pemulihan
- **Greyed-out**: KPI card dalam Dashboard Coach
- **Issue**: Tiada table untuk track recovery reactions

### 6. Auto-Generate Inventory Request (stok ≤ 30%)
- **Schema ready**: `auto_reorder_enabled`, `last_auto_po_at`, `is_auto_generated` columns
- **Belum implement**: Logik auto-create `psy_inventory_request` bila stok rendah
- **Effort**: Sederhana — trigger PG atau cron job

### 7. Email/WhatsApp Notifikasi
- Bila order shipped, payment received, sesi reminder
- Tiada integration ke email service atau WhatsApp API

### 8. Refund Flow UI
- Schema: `psy_payments.status='refunded'` wujud
- UI: Tiada button refund di mana-mana

---

## 🟠 Pending — Schema Ada, UI Belum Lengkap

### 9. Sessions Per Week (Stage 2 & 3)
- **Stage 1 SIAP**: `psy_packages.sessions_per_week` + `session_days_options` ditambah, UI pakej-edit boleh set variants
- **Stage 2 BELUM**: Patient signup flow tarik dari `session_days_options` (sekarang hardcoded fri_sat/sat_sun dalam plan.html)
- **Stage 3 BELUM**: `plan-week.html` tunjuk sub-tabs Sesi 1 / Sesi 2 dengan nota berasingan per sesi
- **Reason tangguh**: Tunggu test pakej OB/NLC/OBG sebenar dengan data baru

### 10. Audit Log
- **Schema + UI siap**: Boleh paparkan dengan resolver UUID → nama
- **Issue**: IP Address column buang dari UI (tak pernah dirakam)
- **Soalan**: Page audit ni penting ke tak? Jawapan user: "kalau tak ada SOP review, buang dari menu tapi keep insert" — belum implement

### 11. Stage 2 Pesakit (Patient Flow)
- ⏭ **Next task** — bina flow lengkap dari signup → KYC → KOB → Pakej → Rawatan

---

## ✅ Recently Fixed (Untuk Reference)

- `created_by_staff` column ditambah ke `psy_patients`
- `full_name`, `phone`, `emergency_contact_email`, `emergency_contact_relationship` ditambah ke `psy_patients`
- `image_url` ditambah ke `psy_products`
- RLS update plan untuk patient (`Patients update own plan setup`)
- Bug 286% check-in Dashboard Coach (filter caseload + cap 7/pesakit + clamp 100%)
- Bug Reschedule KOB tak buka modal (element id salah)
- Bug Lihat butiran tak akses (pageId mismatch)
- 3 jenis Pesakit dalam modal — labels diperbaiki (Baru / Sedang Dalam Rawatan / Pesakit Lama)
- Checkbox column dalam patients table dibuang (dead UI)
- Logic auto-extension bila miss sesi (Pilihan B: 1 minggu tambahan per missed week)
- Backfill 24 sesi kalau setup terganggu separa

---

**File ini akan diupdate setiap kali ada feature ditangguh / disiapkan. Rujuk sebelum tambah scope baru.**


---


# ===== Audit_V1_Syafa.md =====

# Audit V1 — Sistem Pembayaran, Invois/Resit, Perjanjian & Penyelesaian KOB

| | |
|---|---|
| **Versi** | V1 (draf untuk perbincangan) |
| **Tarikh** | 21 September 2026 |
| **Disediakan untuk** | Syafa / pasukan ISW |
| **Skop** | Aliran KOB → cadangan pakej → bayaran → perjanjian → Tandakan Selesai → pakej aktif → ansuran; serta resit, invois, bayaran manual, dan peringatan automatik |
| **Status keseluruhan** | Kod **siap dan di-push** (`origin/main`). **Belum diuji hujung ke hujung dalam pelayar.** Beberapa langkah DB dan deploy perlu disahkan (lihat Bahagian 6) |

> Dokumen ini jujur tentang apa yang **sudah ada**, apa yang **belum dibuktikan**, dan apa yang **sengaja ditangguhkan** untuk perbincangan (Bahagian 9 — Tukar Pakej).

---

## 1. Ringkasan eksekutif

1. **Perjanjian KOB** kini menggunakan tandatangan per muka surat (tab), tanpa cap footer berganda, dengan pilihan **"Tiada waris / penjamin"**.
2. **Resit dan invois** dibina semula ikut format rujukan GHL, dengan nombor berjujukan **REC10001…** dan **INV-000001…** yang disimpan dalam DB (boleh dicari).
3. **Bayaran manual** dijadikan boleh diaudit: dipautkan kepada sasaran sebenar, ada **Bank Reference**, **bukti**, **tarikh & masa sebenar**, **siapa merekod**, dan **jumlah dikunci** mengikut baki.
4. **Bayaran ansuran** mempunyai **dua jenis invois** (tuntutan ansuran, dan gambaran penuh pelan) serta **peringatan automatik** 7 hari dan 2 hari sebelum due dengan pautan HitPay + PDF invois.
5. **Penyelesaian KOB** kini dikawal: **bayaran diselesaikan + perjanjian ditandatangani** wajib sebelum "Tandakan Selesai"; ada butang **Batalkan Selesai** dan **Aktifkan Pakej** (pemulihan).
6. Satu **pepijat sebenar** dijumpai dan dibaiki (pakej tak diaktifkan bila bayaran dibuat selepas KOB "Completed" — kes Tester05).

---

## 2. Aliran semasa (selepas perubahan)

```
KOB dijadualkan → Hadir → Cadang pakej (Patient Proceeds)
   → Bayaran pertama (deposit ATAU penuh)   [kob-detail]
   → Perjanjian ditandatangani              [kob-sign / kob.html]
   → Tandakan Selesai   ← hanya bila bayaran DAN perjanjian lengkap
   → Pakej aktif + pelan rawatan dicipta
   → Ansuran seterusnya                     [Pesakit Hub → Checkpoint Ansuran]
        ├─ Bayar Manual (jumlah dikunci)
        ├─ Hantar WA (pautan HitPay + PDF invois)
        └─ Peringatan automatik (7 & 2 hari sebelum due)
   → Resit (REC) dijana bagi setiap bayaran; invois (INV) ikut pakej/checkpoint
```

**Sekatan tempahan:** ansuran tertunggak (`overdue`) menyekat tempahan sesi baharu; dibuka semula secara automatik bila bayaran mencukupi. Tiada denda (keputusan pengguna).

---

## 3. Apa yang dibina / diubah, ikut modul

### 3.1 Perjanjian KOB
| Perkara | Keadaan |
|---|---|
| Cap tandatangan footer setiap muka surat | **Dibuang** (kob-sign, kob-detail, kob.html pesakit) — hanya tab per muka surat kekal |
| "Tiada waris / penjamin" | Checkbox di staff dan pesakit; nama/IC/tandatangan waris jadi pilihan; PDF menulis "Tiada waris / penjamin" |
| Butang Remove perjanjian | Baiki: dulu kelihatan berjaya tetapi **RLS senyap** (0 baris dipadam). Kini menyemak baris terpadam; policy DELETE staff di prod perlu wujud (**disahkan ada** semasa sesi) |
| Jadual bayaran dalam PDF | Jarak teks-garisan dilaraskan |

### 3.2 Bayaran manual
| Perkara | Keadaan |
|---|---|
| Kaedah | **Bank Transfer** atau **Tunai** sahaja |
| Bank Reference | Lajur `bank_reference`; **wajib untuk transfer** |
| Bukti | Wajib kecuali tunai; disimpan (`receipt_url`), boleh dibuka dari Sejarah Transaksi |
| Tarikh & masa sebenar | Medan datetime → `paid_at` (tak boleh masa hadapan); `created_at` = masa direkod |
| Siapa merekod | `recorded_by` |
| Dipautkan kepada sasaran | `paid_for_type` (`package/installment/invoice/consultation/product/other`), `paid_for_seq` (checkpoint), `paid_for_ref` (invois yang dilunaskan) |
| Pengesahan jumlah | Jumlah **dikunci** ikut baki sasaran; **lebih bayar ditolak** (tiada override); kurang bayar pada pakej tanpa checkpoint → ditanya, ditanda **"Belum Cukup — baki masih tertunggak"** (`is_partial`) |
| Edit / batal bayaran | Butang ✏️/🗑️ (RBAC `payment.edit` / `payment.delete`); batal = status `refunded` (baris **tidak dipadam**), sebab wajib, kira semula status pakej + checkpoint |
| Bayaran pertama di KOB | Direkod **sekali sahaja** di KOB; baki/ansuran seterusnya di Pesakit Hub |
| Bayaran gateway (HitPay/GHL) | **Tak boleh** diedit/dibatal dari UI (perlu refund melalui gateway) |

### 3.3 Resit
- Format RECEIPT ikut GHL (logo, Billed to, Receipt No, Date Paid, Payment Method, **Bank Reference**, jadual item, Subtotal/Discount/Amount Paid).
- **Pecahan bayaran** bagi bayaran pakej: Package Total → Dibayar pada resit ini (Deposit/Installment n/Full) → Jumlah dibayar setakat ini → **Baki**.
- Baris diskaun berlabel: **kod promo** dan **baucar ganjaran** (baucar ditanda `used` oleh trigger DB sedia ada).
- Dwibahasa (BM/EN) ikut bahasa dipilih; PDF WhatsApp **English sahaja** (batasan diketahui).
- Butang 🧾 Resit berada di **Sejarah Transaksi** (bukan di baris checkpoint).

### 3.4 Invois
| Jenis | Tujuan | Kandungan |
|---|---|---|
| **Invois Ansuran** | Tuntutan bayaran satu checkpoint | Item pakej, Subtotal/Discount, **Amount Due = ansuran itu sahaja**, butang Pay/Paid. Nombor `INV-…-n`. Disorok bila ansuran sudah dibayar |
| **Invois Penuh** | Gambaran keseluruhan pelan | Jadual "Payment k of n" (Paid/Pending), Amount Due keseluruhan; boleh dipaparkan **setakat checkpoint tertentu** |
| **Invois bayaran bukan-KOB** | Kedai, sambungan minggu, dll | Dibina daripada baris `psy_payments`; nombor INV auto |

- Harga item untuk pelan ansuran = **Harga Installment (Full)** dalam tetapan pakej (bukan baris "caj" berasingan).
- Invois ansuran/penuh dihantar bersama pautan HitPay sebagai **PDF** melalui WhatsApp (Hantar WA, dan automasi).

### 3.5 Pesakit Hub → Bayaran
- Checkpoint Ansuran: **💵 Bayar Manual**, **📤 Hantar WA**, menu **⋯** (Link Payment, Invois Ansuran, Invois Penuh).
- **Status checkpoint dikira daripada bayaran sebenar** (bukan bendera `met` semata-mata).
- Sejarah Transaksi: lajur **Butiran** (untuk apa), rujukan REC/INV/Bank Ref, 🧾 Resit, 📄 Invois, 📎 Bukti; percubaan **gagal disorok** (ada togol).
- Bahagian "Other": jadual transaksi terus di luar (bukan kad satu-satu).

### 3.6 Peringatan ansuran automatik
- Dalam **Sistem Automasi** (Automation List): automasi **"Peringatan Ansuran Pakej"** (draf) — **7 hari** dan **2 hari** sebelum due, jam 10:00.
- Pembolehubah: `{{ansuran}} {{jumlah}} {{baki}} {{tarikh_due}} {{pautan}}`.
- Pilihan **📎 Lampirkan invois PDF** per mesej; halaman butiran menunjukkan penanda 🔗 dan 📎.
- Hanya ansuran **seterusnya yang belum dibayar** diingatkan; kalau sudah dibayar, tidak dihantar.
- Auto Mesej `installment_reminder` (lama) **mesti kekal OFF** — elak mesej berganda.

### 3.7 Penyelesaian KOB
| Perkara | Keadaan |
|---|---|
| Syarat Tandakan Selesai | **Pakej dicadangkan + bayaran diselesaikan + perjanjian ditandatangani**; gate keras menyemak semula **data terkini DB** |
| "Bayaran diselesaikan" | penuh, dilangkau, atau **deposit ansuran diterima** |
| Senarai semak ✅/⬜ | Dipaparkan di bawah butang |
| **Batalkan Selesai** | Sebab wajib; pakej pilihan dibatalkan sekali (pembelian `cancelled`, pelan `paused`); audit log |
| **Aktifkan Pakej** (pemulihan) | Untuk KOB `completed` tetapi pakej belum aktif dan bayaran diterima |
| Cegah pendua | `markSelesai` tak mencipta pembelian/pelan kali kedua bila pakej sudah aktif |

### 3.8 Lain-lain
- **Dwibahasa**: `iswL()` untuk teks dinamik/prompt; glosari seed dalam `shared/i18n.js` (peraturan disimpan dalam memori projek).
- **Carian**: Pembayaran admin mencari REC / INV / rujukan / ID sistem / nama pesakit; CSV eksport memuat semua nombor.
- **Modal**: resit/invois tak lagi bertindih; Esc menutup; cetak melalui tetingkap bersih (satu A4).

---

## 4. Kawalan dan jejak audit

### 4.1 Kebenaran (RBAC)
| Tindakan | Kunci |
|---|---|
| Rekod bayaran manual (Pembayaran admin) | `payment.create` |
| Edit bayaran manual | `payment.edit` |
| Batal bayaran manual | `payment.delete` |
| Tindakan KOB (Hadir, Selesai, Batalkan Selesai, Aktifkan Pakej, Bayar Manual di KOB) | `kob.edit` |

### 4.2 Audit log (`psy_audit_log`) — tindakan yang direkod
`kob.package_payment_manual` · `payment.manual_recorded` · `kob.payment_edited` · `kob.payment_voided` · `kob.completed` · `kob.completed_cancelled` · `kob.package_activated_after_completed` · `kob.agreement_signed_inline` · `kob.agreement_removed`

### 4.3 Data yang menjejak setiap bayaran (`psy_payments`)
`receipt_no`, `invoice_no`, `bank_reference`, `paid_at` (sebenar), `created_at` (direkod), `recorded_by`, `paid_for_type/seq/ref`, `manual_method`, `is_partial`, `discount`, `receipt_url` (bukti), `notes` (termasuk cap "Diedit/DIBATALKAN oleh … sebab …").

---

## 5. Pepijat dijumpai dan dibaiki dalam kitaran ini

| # | Pepijat | Punca | Baikan |
|---|---|---|---|
| 1 | Remove perjanjian "berjaya" tetapi rekod kekal | RLS DELETE staff tiada di prod; kod tak semak baris terpadam | Semak 0 baris + policy dijumpai wujud |
| 2 | Bayaran berganda (RM 74,400 + RM 6.2 juta) | Dua tempat rekod bayaran, tiada had baki | Had baki, bayaran KOB sekali sahaja, batal/edit dengan RBAC |
| 3 | Checkpoint "Completed" tanpa transaksi | Status `met` dalam DB tak sepadan bayaran | Status dikira daripada bayaran sebenar |
| 4 | Modal resit "tak boleh ditutup" | Modal bertindih (butang ditekan berulang semasa memuat) | Halang pendua, Esc, pengendali eksplisit |
| 5 | Cetak resit jadi 2 muka surat | `window.print()` pada halaman induk | Tetingkap cetak bersih |
| 6 | Resit dari Pesakit Hub tiada REC/pecahan | Data resit tak lengkap dimuatkan | Muat semua medan diperlukan |
| 7 | **Pakej tak diaktifkan selepas bayaran (kes Tester05)** | Kod pengaktifan hanya untuk status `declined`, sedangkan *Patient Proceeds* menetapkan `pending` | Syarat diluaskan + butang Aktifkan Pakej |
| 8 | Banner "Pakej telah dibuka" salah | Hanya semak nama pakej | Semak `active_package_id` |
| 9 | Selesai tanpa bayaran boleh terlepas | Gate keras tiada semakan bayaran | Semakan bayaran + perjanjian pada data terkini |
| 10 | Kegagalan PDF invois senyap | Ralat ditelan | Banner ralat jelas |

---

## 6. Status pelaksanaan (perlu disahkan)

### 6.1 Migration DB (`supabase/migrations/`)
| Fail | Kandungan | Prod | Testing |
|---|---|---|---|
| `20260921_invoice_receipt_numbers.sql` | `receipt_no`, `invoice_no`, `discount`, `package_discount`, jujukan + trigger | Disahkan wujud (semakan 21 Sept) | Dijalankan (dilapor pengguna) |
| `20260921b_payments_manual_method.sql` | `manual_method` | Disahkan wujud | Dijalankan (dilapor pengguna) |
| `20260921c_payment_invoice_no.sql` | `invoice_no` untuk bayaran bukan-KOB | Dijalankan (dilapor pengguna) | Dijalankan (dilapor pengguna) |
| `20260921d_seed_installment_reminder_automation.sql` | Seed automasi draf | Dijalankan (dilapor pengguna) | Dijalankan (dilapor pengguna) |
| `20260921e_automation_attach_invoice.sql` | `attach_invoice` | Dijalankan (dilapor pengguna) | Dijalankan (dilapor pengguna) |
| `20260921f_manual_payment_audit.sql` | `bank_reference`, `recorded_by`, `paid_for_*`, `is_partial` | Dijalankan (dilapor pengguna) | Dijalankan (dilapor pengguna) |

> Pengguna melaporkan (21 Sept 2026) **semua migration telah dijalankan**. Hanya `20260921` dan `b` disahkan sendiri melalui semakan DB prod; selebihnya bergantung pada laporan pengguna — disyorkan sahkan dengan pertanyaan lajur (lihat semakan dalam sesi audit).

### 6.2 Edge function (`supabase/dashboard-paste/` untuk paste dashboard)
`kob-invoice-pdf` (baharu) · `payments-send-receipt` · `payments-webhook` · `payments-initiate` · `automations-runner`
Pengguna melaporkan **semua sudah di-deploy** (21 Sept 2026). Rahsia diperlukan: `PUBLIC_APP_URL` (**disahkan sudah ada**), `CRON_SECRET`, `GHL_*`, `HITPAY_*`.

### 6.3 Pengujian
| Kawasan | Status |
|---|---|
| Semakan sintaks semua fail diubah | Lulus (automatik) |
| Render resit/invois (data palsu, BM & EN) | Lulus |
| Penjana PDF invois (Node) + pautan boleh klik | Lulus |
| **Ujian dalam pelayar / hujung ke hujung** | **Sebahagian** oleh pengguna (modal resit, sejarah transaksi, checkpoint); **borang bayaran manual baharu, Hantar WA + PDF, peringatan automatik, Batalkan Selesai, Aktifkan Pakej belum disahkan** |

---

## 7. Senarai semak audit (untuk dijalankan oleh penyemak)

**A. Bayaran manual**
- [ ] Borang di Pembayaran admin: "Bayaran untuk" wajib; jumlah dikunci; transfer tanpa Bank Reference **ditolak**; tanpa bukti (bukan tunai) **ditolak**; tarikh masa hadapan **ditolak**.
- [ ] Bayaran ansuran: resit REC dijana, `paid_at` = tarikh dimasukkan, `recorded_by` = staf, baki dikira semula.
- [ ] Lebih bayar ditolak; edit tak boleh melebihi baki.
- [ ] Batal bayaran: baris jadi `refunded`, status pakej/checkpoint dikira semula, audit log wujud.

**B. Resit & invois**
- [ ] REC unik dan berjujukan; INV unik.
- [ ] Invois Ansuran: Amount Due = ansuran itu sahaja; hilang bila sudah dibayar.
- [ ] PDF WhatsApp: format baharu + Bank Reference (perlu `payments-send-receipt` terkini).

**C. Automasi**
- [ ] "Peringatan Ansuran Pakej" diaktifkan; ansuran ujian dengan due 7 hari → mesej + PDF sampai; ansuran sudah dibayar → **tiada** mesej.

**D. KOB**
- [ ] Tandakan Selesai **dikunci** sehingga bayaran + perjanjian lengkap.
- [ ] Batalkan Selesai (dengan/tanpa batal pakej); Selesai semula **tidak** mencipta pelan berganda.
- [ ] Kes seperti Tester05: KOB `completed`, pakej belum aktif → butang Aktifkan Pakej berfungsi.

---

## 8. Isu diketahui dan jurang

| # | Perkara | Kesan | Cadangan |
|---|---|---|---|
| 1 | Bayaran KOB **pertama** tiada dropdown "Bayaran untuk" | Hanya `paid_for_type='package'` disimpan | Selaraskan dengan Pembayaran admin |
| 2 | Kurang bayar hanya dibenderakan untuk pakej **tanpa checkpoint** | Ansuran dikunci, jadi tak boleh kurang | Terima; atau benarkan bayaran separa ansuran (perlu peraturan) |
| 3 | PDF WhatsApp **English sahaja** | Pesakit BM terima PDF English | Tentukan bahasa ikut pesakit |
| 4 | Halaman Ledger (GHL) tak dikemas kini untuk medan baharu | Bank Ref/REC tak dipaparkan di sana | Sambung jika perlu |
| 5 | Bayaran manual **tak mengambil promo/baucar** automatik | Diskaun hanya pada bayaran gateway atau medan diskaun pakej | Putuskan sama ada perlu |
| 6 | Deposit ansuran dikira "bayaran diselesaikan" untuk Selesai | Baki diuruskan di Pesakit Hub | Sahkan dasar |
| 7 | Pesakit "tak teruskan" (declined) kini memerlukan perjanjian | Selaras gate keras sedia ada | Sahkan dasar |
| 8 | Nombor invois ansuran `INV-…-n` (bukan jujukan sendiri) | Berbeza dengan GHL (INV-002689) | Putuskan sama ada jujukan sendiri perlu |
| 9 | Hantar WA jana pautan baharu setiap kali | Pautan lama ditanda `failed/superseded` | Terima (mengelak baris pending berganda) |
| 10 | Tiada UI paparan audit trail sejarah bayaran (hanya log/DB) | Semakan audit perlu SQL | Halaman audit ringkas |

---

## 9. Ditangguhkan untuk perbincangan — **Tukar / Naik Taraf Pakej**

**Status: TIDAK dibina.** Kenapa perlu dibincang dahulu: menukar pakej selepas diaktifkan **mengubah semua dimensi serentak**, jadi keputusan mesti selaras.

| Dimensi | Persoalan yang perlu diputuskan |
|---|---|
| **Payment** | Bayaran sedia ada dikreditkan? Harga pakej baharu guna tier **semasa** atau yang **dibekukan** di KOB? Beza harga → invois baharu; lebih bayar → pulangan/manual? Jadual ansuran dijana semula? |
| **Agreement** | Perlu **perjanjian baharu** (kandungan pakej/klausa berbeza) atau **addendum**? Perjanjian lama kekal sebagai rekod? |
| **Schedule** | Pelan lama `paused` dan pelan baharu bermula **minggu 1** atau **menyambung**? Sesi yang sudah berlalu/ditempah dikendalikan bagaimana? Override per-minggu dibawa? |
| **Supplies (bekalan)** | Bekalan ikut pakej (dan override per-minggu): pesakit dengan bekalan sudah diberi — dikira baki atau ditetapkan semula? Kesan stok/inventori? |
| **Kawalan** | Siapa boleh (RBAC khas)? Sebab wajib? Had frekuensi? Audit log? |
| **Sejarah** | Pakej lama ditanda "ditukar ke …", bukan dipadam; laporan kewangan/komisen affiliate bagaimana? |

**Batasan semasa (jangan guna sebagai jalan pintas):** "Patient Proceeds" berulang pada KOB **menimpa harga dan menetapkan bayaran `pending`** tanpa mengira bayaran sedia ada — ini punca kekeliruan kes Tester05.

**Cadangan awal** (untuk dibincang, bukan keputusan): butang "Tukar Pakej" di Pesakit Hub dengan ringkasan kredit/baki sebelum sahkan; pakej lama `cancelled` (rujukan "ditukar"), pelan lama `paused`, pelan baharu dicipta; default harga semasa, menyambung minggu semasa, lebih bayar ditanda manual.

---

## 10. Lampiran

### 10.1 Fail utama
| Kawasan | Fail |
|---|---|
| Resit/invois | `shared/receipt.js`, `shared/invoice.js`, `supabase/functions/_shared/receipt_pdf.ts`, `_shared/invoice_pdf.ts`, `_shared/kob_invoice.ts`, `kob-invoice-pdf/` |
| Bayaran manual | `roles/staff/payment-admin.html`, `roles/staff/patient-hub.html`, `roles/staff/kob-detail.html`, `shared/kobPayments.js` |
| Perjanjian | `roles/staff/kob-sign.html`, `roles/staff/kob-detail.html`, `roles/patient/kob.html` |
| Automasi | `roles/staff/automation-builder.html`, `automation-detail.html`, `variables-library.html`, `supabase/functions/automations-runner/` |
| Pesakit | `roles/patient/payment-plan.html`, `sejarah-pembayaran.html` |
| Skema | `database/schema/06_payments.sql`, `09_kob.sql`, `37_automation_sequences.sql`; `database/master_migration.sql` (dijana) |

### 10.2 Commit (dari `b89a4d8` hingga `cbc370b`)
Sejarah penuh: `git log --oneline b89a4d8..cbc370b`. Kumpulan utama: perjanjian (`02ec71e`, `9d225ba`, `9061ada`), kawalan bayaran (`3f4b38f`, `bbe220a`), resit/invois (`e2c9fa9` → `43ab605`), bayaran manual boleh diaudit (`3d44576`), automasi (`260b98b` → `e13ae07`), KOB (`fceef4b`, `9c5c708`, `cbc370b`).

---

*Dokumen ini menggambarkan keadaan kod pada commit `cbc370b`. Sebarang perubahan selepas itu perlu dikemas kini di sini.*


---


# ===== Fasa2_Pengesahan_Sesi.md =====

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
- Template WA — edit terus di sini. Pembolehubah: `{nama}`, `{sesi_akan_datang}`,
  `{tarikh_sesi}`, `{masa_sesi}`, `{nama_klinik}` — set kanonik, sama nama
  digunakan di **Variables Library** (kategori "Temujanji", 🗓️) dan di
  **Test Automation**, supaya pratonton/hantar-ujian papar nilai sebenar
  (bukan `{sesi_akan_datang}` mentah). Elak guna `{tarikh}`/`{masa}` polos —
  itu bermaksud *tarikh/masa hari ini* (pembolehubah Sistem sedia ada),
  bukan tarikh sesi.

## Cara Test

**A) Test hantar SATU mesej (tanpa tunggu cron/jadual):**
Guna `roles/staff/test-automation.html` → pilih template "Pengesahan Sesi
Rawatan" (dalam kumpulan **Template**) → pilih pesakit ujian yang **ada sesi
`booked` akan datang** (kalau tiada, `{sesi_akan_datang}`/`{tarikh_sesi}`/
`{masa_sesi}` akan kosong dalam pratonton — ini normal, bukan ralat) →
saluran WhatsApp → hantar. Ini hantar **terus** (bukan tunggu jam 10 pagi),
bagus untuk semak wording & format.
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

⚠️ **Jika step91 pernah di-run sebelum ni** (versi lama guna `{sesi}`/
`{pautan}`/`{klinik}`): step91 kini guna `ON CONFLICT ... DO UPDATE`, jadi
run semula fail ni akan **kemas kini** baris `session_confirm` sedia ada ke
versi terkini. `is_active` TIDAK disentuh (toggle staff kekal).

1. **Run SQL** `database/step91_session_confirm.sql` di **TESTING** & **PROD**
   (idempotent — selamat run berulang). Mesti run **sebelum/serentak** deploy
   frontend.
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


---


# ===== Mesej_Automatik_Panduan.md =====

# Panduan Modul "Mesej Automatik" (Automation) — ISW

> Modul hantar mesej automatik/broadcast kepada pesakit melalui WhatsApp, In-App & Email.
> Semua data adalah **sebenar** — tiada metrik palsu. Yang tak dijejak dinyatakan jujur.
> Kemas kini: 10 Julai 2026.

---

## 1. Gambaran Keseluruhan (Architecture ringkas)

```
Staff (UI)  ─cipta/edit─►  psy_automations ──┐
                                             │ (cron 15 min)
Enjin: supabase/functions/event-reminders ◄──┘
   │  1. Baca automasi aktif (trigger 'schedule')
   │  2. Tapis penerima  → applyConds()  (guna psy_patients / psy_audiences)
   │  3. Isi pembolehubah → buildPatientVars()  (psy_patients + pakej + coach + plan + klinik)
   │  4. Hantar via GHL   → WhatsApp / In-App / Email
   └► Rekod setiap hantaran → psy_notification_logs (sent / failed / pending)
                                             │
Staff (UI)  ◄──papar Dashboard/Log/Detail────┘
```

**Jadual data utama:**
| Jadual | Peranan |
|---|---|
| `psy_automations` | Definisi automasi: pencetus, syarat, tindakan, mesej, jadual, status |
| `psy_notification_logs` | Rekod setiap hantaran: status (sent/failed/pending), saluran, pesakit |
| `psy_audiences` | Set kriteria sasaran bernama (guna semula) |
| `psy_auto_messages` | Template mesej + mesej sistem (kategori, bahasa, tag) |
| `psy_patients` / `psy_packages` / `psy_profiles` / `psy_treatment_plans` | Sumber data pembolehubah |

**Enjin:** `supabase/functions/event-reminders/index.ts` — dicetus cron setiap 15 minit. Fungsi teras: `runScheduledAutomations()` → `applyConds()` → `buildPatientVars()` → `logAuto()`.

---

## 2. Peta Halaman (Navbar: Komunikasi → Mesej Automatik)

| # | Halaman | Fail | Tujuan |
|---|---|---|---|
| 1 | **Dashboard** | `automation-dashboard.html` | Gambaran harian: KPI, trend, queue, status automasi |
| 2 | **Senarai Automasi** | `automations.html` | Semua automasi (termasuk broadcast) — jadual, filter, on/off, padam |
| 3 | **Cipta / Edit Automasi** | `automation-builder.html` | Borang 5-langkah bina automasi |
| 4 | **Template Mesej** | `auto-mesej.html` | Urus mesej sistem sedia ada (broadcast, peringatan) |
| 5 | **Variables Library** | `variables-library.html` | Senarai pembolehubah + pratonton data sebenar |
| 7 | **Audience** | `automation-audience.html` | Cipta set sasaran + anggaran hidup |
| 8 | **Queue / Scheduled** | `automation-queue.html` | Automasi berjadual akan datang |
| 9 | **Log Penghantaran** | `automation-logs.html` | Rekod hantaran + Export CSV |
| 10 | **Butiran Automasi** | `automation-detail.html` | Prestasi + konfigurasi satu automasi |
| 11 | **Test Automation** | `test-automation.html` | Hantar ujian sebenar sebelum aktif |

> *Analytics DIBUANG* — bertindih dengan Dashboard + banyak metrik (Dibaca/Respon) tak dijejak.

---

## 3. Cara Guna Setiap Halaman

### 1) Dashboard
- **Tujuan:** pantau kesihatan automasi harian.
- **Ada apa:** 5 KPI (dengan delta vs tempoh lepas), carta trend, donut saluran, queue hari ini, status automasi (aktif/draf/dijeda), quick actions.
- **Pemilih julat tarikh** di atas (7/14/30 hari/bulan/custom).
- **Data:** `psy_notification_logs` + `psy_automations`.

### 2) Senarai Automasi
- **Tujuan:** urus semua automasi.
- **Tindakan:** 👁 Lihat (→ Detail) · ✎ Edit (→ Builder) · ⏸/▶ jeda/aktif · 🗑 padam.
- **Filter:** carian, kategori, status, saluran.
- Broadcast muncul di sini sebagai kategori **"Broadcast"** (pencetus jadual).

### 3) Cipta / Edit Automasi (5 langkah)
1. **Pencetus** — kategori + event (cth Broadcast Berjadual, Rujukan Dibuat).
2. **Syarat** — sasaran pesakit; boleh **guna Audience Tersimpan** atau tetap sendiri (status/pakej/jantina/umur/negeri).
3. **Tindakan** — saluran hantar (WhatsApp / In-App / Email).
4. **Kandungan Mesej** — teks + pembolehubah (guna template atau tulis sendiri).
5. **Semakan** — sahkan & simpan.
- **Nota:** kategori/event ialah *registry dalam kod* (bukan boleh-edit UI) supaya tiada pilihan "mati".

### 4) Template Mesej (galeri)
- **Tujuan:** simpan ayat mesej boleh guna semula.
- **"+ Tambah Template"** & **Edit** (untuk template) → Template Builder.
- Mesej *sistem* (cth Saranan Rujukan) diedit melalui modal.

### 5) Template Builder (editor penuh)
- **Kiri:** Nama · Saluran · Kategori · Bahasa · Tag · Penerangan · Status · metadata (Dicipta Oleh/Tarikh).
- **Tengah (bertab):** *Kandungan Mesej* (toolbar B/I/S/mono/senarai + **Insert Variable** + Pembolehubah Digunakan) · *Tetapan Lanjutan* (Butang/Lampiran/Fallback = "Akan datang").
- **Kanan:** Pratonton WhatsApp + Senarai Pembolehubah berkategori + Tips.
- **Hantar Ujian** — hantar mesej ujian sebenar via GHL.

### 6) Variables Library
- **Tujuan:** rujukan semua pembolehubah yang **betul-betul diisi** sistem.
- Cari, tab kategori, salin satu/semua, **Preview** guna pesakit sebenar.
- Kategori: **Pesakit · Pakej & Rawatan · Coach & Klinik · Sistem · Temujanji**.
- Pembayaran ditanda *"perlu pencetus khusus"* (belum disenarai).

### 7) Audience (Cipta Audience)
- **Tujuan:** simpan set sasaran bernama untuk guna semula.
- **Kriteria:** Status · Pakej · Jantina · Umur · Negeri · Tarikh Pendaftaran.
- **Anggaran hidup** (donut + pecahan jantina/umur/negeri/pakej) update serta-merta.
- Simpan → `psy_audiences` → boleh pilih dalam Builder (langkah Syarat).

### 8) Queue / Scheduled
- **Tujuan:** lihat automasi berjadual yang **akan** dihantar.
- Jadual: masa seterusnya, automasi, kategori, jadual, saluran, penerima.

### 9) Log Penghantaran
- **Tujuan:** rekod penuh setiap hantaran.
- Filter (status/saluran/automasi) + **Export CSV**.

### 10) Butiran Automasi
- **Hero:** ikon saluran + nama + status + meta (Saluran/Kategori/Audiens/Dicipta Oleh/ID) + panel status.
- **Ringkasan Prestasi:** Audiens · Diproses · Berjaya · Gagal · Kadar (30 hari).
- **Status Penghantaran** (bar) · **donut Saluran** · Pratonton · Pencetus · Sasaran · Aktiviti Terkini · **Export Log**.

### 11) Test Automation
- 4 langkah: pilih automasi/template → pilih pesakit (carian) → pilih saluran → **Hantar Ujian Sekarang**.
- Hantar **sebenar**: WhatsApp (GHL) + In-App (`psy_notifications`); mesej diisi data pesakit betul.
- Keputusan: Status + Masa Dihantar sebenar; Disalurkan/Dibaca/Respon = *tidak dijejak*.

---

## 4. Sistem Pembolehubah (Variables)

- **Format:** `{{kunci}}` (dua kurungan). Contoh: `{{nama}}`, `{{pakej}}`, `{{minggu}}`.
- **Kunci Bahasa Melayu** (konsisten seluruh sistem).
- Enjin isi guna `buildPatientVars()` — sumber data sebenar:

| Kategori | Contoh kunci | Sumber |
|---|---|---|
| Pesakit | nama, mrn, ic, telefon, emel, jantina, negeri, umur | `psy_patients` |
| Pakej & Rawatan | pakej, kod_pakej, minggu, jumlah_minggu, tarikh_mula, tarikh_tamat | `psy_patients` + `psy_packages` + `psy_treatment_plans` |
| Coach & Klinik | coach, nama_klinik, telefon_klinik, alamat_klinik | `coach_id`→`psy_profiles` + pemalar klinik |
| Sistem | tarikh, masa, hari, tahun, bulan | tarikh sistem (GMT+8) |
| Temujanji | (sesi rawatan terdekat "Ditempah") | sumber sesi pesakit |

> Pembayaran belum disenarai — perlu pencetus event pembayaran.

---

## 5. Kejujuran Data (Had Semasa)

 Diguna secara konsisten seluruh modul — **tidak** dipapar sebagai palsu:
- **Dibaca / Respon** — GHL hantar teks biasa; tiada read-receipt/webhook balasan. **Tidak dijejak.**
- **SMS** — dibuang (guna WhatsApp).
- **Retry automatik** — belum ada dalam enjin.
- **Butang WhatsApp / Lampiran / Fallback** — "Akan datang" (GHL teks biasa).
- Metrik `0` bermakna **belum ada hantaran**, bukan ralat.

---

## 6. Senarai Semak Deploy PROD (xmvqvq — MCP tiada akses, run manual)

1. Run SQL di Supabase (ikut turutan):
   - `step84` — RLS staff kemas kini profil pesakit **(WAJIB)**
   - `step85` — seed template saranan **(optional; ada fallback)**
   - `step86` — `psy_automations` + `psy_notification_logs` **(WAJIB)**
   - `step87` — `psy_audiences` **(WAJIB)**
   - `step88` — kolum `status` automasi **(WAJIB)**
   - `step89` — `category` + `language` template **(WAJIB)**
   - `step90` — `tags` + `created_by` template **(WAJIB)**
2. **Redeploy** Edge Function `event-reminders` (enjin + pembolehubah) — **WAJIB (testing & prod)**.
3. Set secrets: `GHL_ISW_TOKEN`, `GHL_ISW_LOCATION_ID`, `CRON_SECRET`, `GHL_EMAIL_FROM`.
4. Set **cron 15-minit** panggil fungsi (header `x-cron-secret`).
5. **Cutover broadcast lama** (elak hantar 2×): pindah `recurring_broadcast` dari `psy_auto_messages` → `psy_automations`, matikan `runBroadcasts`.

---

## 7. Aliran Hujung-ke-Hujung (contoh)

1. Staff cipta automasi *"Peringatan Check-in Harian"* (Builder) → simpan ke `psy_automations` (status: aktif).
2. Cron cetus enjin tiap 15 min → enjin jumpa automasi ini pada masa jadual.
3. `applyConds()` tapis pesakit layak (cth: status aktif, pakej OBD).
4. `buildPatientVars()` isi `{{nama}}`, `{{minggu}}`, dll untuk setiap pesakit.
5. Hantar via GHL (WhatsApp) / In-App / Email.
6. Setiap hantaran direkod ke `psy_notification_logs` (sent/failed).
7. Staff pantau di **Dashboard / Log / Butiran Automasi**.
```
```
```

Lihat juga: `docs/Mesej_Automatik_Prompt_Architecture.md` untuk prompt jana rajah flow di GPT/Claude.


---


# ===== Mesej_Automatik_Prompt_Architecture.md =====

# Prompt — Jana Rajah Flow / Architecture (GPT / Claude)

Salin **seluruh blok** di bawah dan tampal ke GPT atau Claude. Ia akan hasilkan
rajah Mermaid (flowchart + sequence) untuk modul Mesej Automatik ISW.

---

```
You are a software architect. Produce clear architecture & flow diagrams (Mermaid syntax)
for the "Automated Messaging" (Mesej Automatik) module of the ISW (Ibnu Sina Wellness)
psychotherapy admin system. Output: (A) a component/architecture diagram, (B) an
end-to-end sequence diagram, and (C) a short legend. Use Mermaid so I can render it.

CONTEXT — TECH STACK
- Frontend: static HTML + inline JS + Tailwind, talking directly to Supabase (client-side).
- Backend: Supabase Postgres + Row Level Security; one Deno Edge Function as the engine.
- Messaging: GoHighLevel (GHL) API for WhatsApp & Email. In-App = rows in a notifications table.
- Scheduler: a cron job hits the Edge Function every 15 minutes.

DATABASE TABLES
- psy_automations       : automation definitions (trigger_category, trigger_event,
                          trigger_timing[jsonb schedule/before/after], conditions[jsonb],
                          conditions_enabled, actions[whatsapp|inapp|email], message_template,
                          status[draft|active|paused], last_run_at).
- psy_notification_logs : one row per send attempt (status sent|failed|pending, channel,
                          patient_id, automation_id, message, error, created_at).
- psy_audiences         : saved, named targeting criteria (conditions jsonb), reusable.
- psy_auto_messages     : reusable message templates + system messages (category, language,
                          tags, message_template, trigger_type).
- psy_patients, psy_packages, psy_profiles, psy_treatment_plans : data sources for variables.

ENGINE (Edge Function: event-reminders)
- Triggered by cron every 15 min.
- runScheduledAutomations(): reads active automations with schedule trigger, checks day/time,
  dedupes once/day via last_run_at.
- applyConds(): filters patients by conditions (patient_status, gender, package, state, age,
  registered date). Conditions may come from an inline set OR a saved psy_audiences record.
- buildPatientVars(): fills message variables ({{nama}}, {{pakej}}, {{minggu}}, {{coach}},
  {{tarikh}}, {{telefon_klinik}}, etc.) from patient + package + coach + treatment plan +
  clinic constants + system date.
- Sends via GHL (WhatsApp/Email) or inserts In-App notification, then writes psy_notification_logs.

UI PAGES (staff)
- Dashboard, Senarai Automasi (list), Cipta/Edit Automasi (5-step builder),
  Template Mesej (gallery), Template Builder (editor), Variables Library, Audience builder,
  Queue/Scheduled, Log Penghantaran (logs), Butiran Automasi (detail), Test Automation.

ACTORS
- Staff (admin/coach) using the UI.
- Cron scheduler.
- Edge Function engine.
- GHL (external messaging).
- Patient (recipient).

KEY FLOWS TO SHOW
1. Staff creates/edits an automation in the Builder → saved to psy_automations.
2. Staff optionally creates an Audience (psy_audiences) reused by automations.
3. Staff creates message Templates (psy_auto_messages) with variables.
4. Cron → engine → applyConds (patients/audience) → buildPatientVars → GHL/In-App → logs.
5. Staff sends a manual Test (Test Automation page) → GHL/In-App directly, not counted in stats.
6. Staff monitors results via Dashboard / Logs / Detail (reads psy_notification_logs).

HONESTY CONSTRAINTS (reflect as notes on the diagram)
- Read receipts & responses are NOT tracked (GHL sends plain text). Only sent/failed/pending.
- SMS channel is intentionally excluded.
- No automatic retry yet.

Please output:
(A) Mermaid `flowchart` of components (UI pages, tables, engine, cron, GHL, patient) with
    arrows for read/write, grouped in subgraphs (Frontend / Database / Engine / External).
(B) Mermaid `sequenceDiagram` for the scheduled-send flow (Cron → Engine → DB → GHL → Patient → Logs → Staff).
(C) A short bullet legend explaining the honesty constraints.
Keep labels concise. Malay labels are fine where natural.
```

---

### Petua
- Kalau nak rajah lebih ringkas: tambah *"Keep it high-level, max 15 nodes."*
- Kalau nak fokus satu aliran: buang bahagian lain, minta **hanya sequence diagram**.
- Untuk render Mermaid: guna https://mermaid.live atau sambungan Markdown yang menyokong Mermaid.


---


# ===== Payment.md =====

# 💳 Payment — Hub Index

Peta **semua fail sistem bayaran ISW**, disusun ikut **4 lapisan**.

> ⚠️ Fail sebenar **tidak** disimpan dalam folder ini — ia kekal di lokasi asal kerana
> Supabase (Edge Function mesti folder terus di `functions/<nama>/`) dan routing halaman
> memerlukan begitu. Folder `payment/` ini hanya **peta rujukan** supaya senang cari semua
> bahagian bayaran dari satu tempat.

Reka bentuk **provider-agnostic**: HitPay hari ini, tukar **Fiuu** nanti = tulis satu adapter
baru (Layer 3) sahaja. Layer 1, 2, 4 tidak berubah.

---

## 🔁 Aliran bayaran (ringkas)

```
Pesakit klik Pay
  → [L1] processPayment()  ──POST──▶  [L2] payments-initiate
                                         · sahkan harga server-side
                                         · cipta psy_payments status=pending (+intent)
                                         · [L3] adapter → [L4] HitPay
  ◀──── redirect ke URL checkout HitPay ────
Pesakit bayar di HitPay
  → [L4] HitPay ──webhook──▶ [L2] payments-webhook
                                · [L3] adapter sahkan HMAC
                                · fulfillOrder() → aktif pakej/plan/KOB/order
                                · psy_payments status=completed
  → [L1] handlePaymentReturn() poll status → papar resit
```

**Prinsip:** pakej/plan diaktifkan **hanya selepas** webhook sahkan bayaran — bukan di client.

---

## 🧱 Layer 1 — UI / Client
Kumpul niat bayaran, redirect ke gateway, papar status. *Tak tahu apa itu HitPay.*

- [../roles/patient/payment.html](../roles/patient/payment.html)
  - `processPayment()` — initiate + redirect
  - `handlePaymentReturn()` — poll status bila pesakit balik (`?ref=…`)

## 🧠 Layer 2 — Orkestra (Edge Functions)
Sahkan harga, simpan pending, fulfillment selepas bayaran sah. *Tak tahu apa itu HitPay.*

- [../supabase/functions/payments-initiate/index.ts](../supabase/functions/payments-initiate/index.ts) — mula bayaran + sahkan harga
- [../supabase/functions/payments-webhook/index.ts](../supabase/functions/payments-webhook/index.ts) — sahkan HMAC + `fulfillOrder()` idempotent

## 🔌 Layer 3 — Adapter (soket tukar-ganti) ⭐
Satu-satunya tempat yang tahu HitPay. Tukar gateway = tambah fail di sini sahaja.

- [../supabase/functions/_shared/payments/types.ts](../supabase/functions/_shared/payments/types.ts) — kontrak neutral (`PaymentProvider`)
- [../supabase/functions/_shared/payments/hitpay.ts](../supabase/functions/_shared/payments/hitpay.ts) — adapter HitPay (createPayment + verifyWebhook)
- [../supabase/functions/_shared/payments/index.ts](../supabase/functions/_shared/payments/index.ts) — pemilih provider (`PAYMENT_PROVIDER`)
- `fiuu.ts` — *(belum ada — tambah di sini bila migrasi ke Fiuu)*

## 🏦 Layer 4 — Gateway (luar sistem)
HitPay → FPX / kad / e-wallet → duit masuk. Nanti boleh tukar Fiuu.

---

## 🗄️ Sokongan (bukan layer)

- **DB migration:** [../database/step94_payment_gateway.sql](../database/step94_payment_gateway.sql)
  — kolum gateway pada `psy_payments` (gateway_provider, gateway_ref, gateway_status, intent, fulfilled_at)
- **Panduan deploy penuh:** [../docs/Payment_Gateway_HitPay.md](../docs/Payment_Gateway_HitPay.md)
  — migration, secrets, deploy, uji sandbox, cara tukar Fiuu

---

## ✅ Status & langkah seterusnya

**Siap (kod):** semua 4 layer + migration + docs.

**Pending (anda):**
1. Daftar HitPay sandbox → dapatkan `HITPAY_API_KEY` + `HITPAY_SALT`
2. Run `step94` (testing+prod) → `supabase secrets set …` → deploy 2 function
   (webhook **wajib** `--no-verify-jwt`)
3. Uji end-to-end sandbox

Lihat [../docs/Payment_Gateway_HitPay.md](../docs/Payment_Gateway_HitPay.md) untuk arahan penuh.


---


# ===== Payment_Gateway_HitPay.md =====

# Payment Gateway — HitPay (provider-agnostic)

Sistem bayaran ISW kini boleh terima **duit sebenar** melalui gateway, menggantikan
simulasi lama (`setTimeout` + tulis resit terus di client).

Reka bentuk **provider-agnostic** — HitPay hari ini, boleh tukar **Fiuu** nanti dengan
menulis satu adapter baru sahaja. Kod client, DB, dan Edge Function tidak berubah.

---

## Seni bina — 4 lapisan

| Lapisan | Fail | Tahu HitPay? |
|--------|------|:---:|
| 1. UI / Client | `roles/patient/payment.html` → `processPayment()` | ❌ |
| 2. Orkestra | `supabase/functions/payments-initiate` + `payments-webhook` | ❌ |
| 3. **Adapter** ⭐ | `supabase/functions/_shared/payments/hitpay.ts` | ✅ (satu-satunya) |
| 4. Gateway | HitPay (FPX / kad / e-wallet) | — |

**Aliran bayaran:**
1. Pesakit klik *Pay* → `processPayment()` panggil `payments-initiate`
2. `payments-initiate` sahkan harga server-side → cipta baris `psy_payments` **status=`pending`**
   (simpan `intent` = pendingItems) → panggil adapter → dapat URL HitPay → redirect pesakit
3. Pesakit bayar di HitPay → HitPay panggil `payments-webhook` (server-ke-server)
4. `payments-webhook` sahkan HMAC → **fulfillOrder()** (aktif pakej/plan/KOB/order) →
   tanda `psy_payments` **status=`completed`**
5. Pesakit kembali ke `payment.html?ref=…` → poll status → papar resit

> **Prinsip penting:** pakej/plan hanya diaktifkan **selepas** webhook sahkan bayaran —
> bukan di client. Ini elak pesakit dapat pakej tanpa bayar.

---

## 1) Jalankan migration

Di Supabase SQL Editor — **TESTING dulu**, kemudian **PROD (xmvqvq)**:

```
database/step94_payment_gateway.sql
```

Menambah pada `psy_payments`: `gateway_provider`, `gateway_ref`, `gateway_status`,
`intent` (JSONB), `fulfilled_at` + benarkan `payment_method='gateway'` + index `gateway_ref`.

---

## 2) Set secrets (Edge Function)

Dapatkan kunci dari **HitPay Dashboard → Settings → API Keys**
(guna **Sandbox** dulu untuk uji tanpa duit betul).

```bash
supabase secrets set \
  PAYMENT_PROVIDER=hitpay \
  HITPAY_MODE=sandbox \
  HITPAY_API_KEY=xxxxxxxx \
  HITPAY_SALT=xxxxxxxx
```

`SUPABASE_URL` & `SUPABASE_SERVICE_ROLE_KEY` di-inject automatik oleh Supabase.

Bila sedia untuk LIVE: tukar `HITPAY_MODE=live` + kunci akaun live.

---

## 3) Deploy Edge Functions

```bash
# initiate — perlukan JWT (pesakit log masuk)
supabase functions deploy payments-initiate

# webhook — PUBLIC (HitPay panggil tanpa JWT). WAJIB --no-verify-jwt
supabase functions deploy payments-webhook --no-verify-jwt
```

> ⚠️ `payments-webhook` **mesti** `--no-verify-jwt` — kalau tidak HitPay tak boleh panggil.
> Keselamatan datang dari HMAC (`HITPAY_SALT`), bukan JWT.

URL webhook (diberi automatik kepada HitPay oleh `payments-initiate`):
`https://<project>.supabase.co/functions/v1/payments-webhook`

---

## 4) Uji (sandbox)

1. Log masuk sebagai pesakit → ada invois belum bayar → klik **Pay**
2. Diredirect ke halaman HitPay sandbox → guna kad ujian HitPay
3. Selepas bayar → kembali ke `payment.html` → tunggu 1-2 saat →
   banner "Pembayaran berjaya" + resit muncul + pakej/plan aktif
4. Semak `psy_payments`: `status=completed`, `gateway_status=completed`, `fulfilled_at` terisi

**Debug:** `supabase functions logs payments-webhook`

---

## 5) Tukar ke Fiuu nanti — apa yang berubah

Hanya **Lapisan 3**:

1. Tulis `supabase/functions/_shared/payments/fiuu.ts` (patuh `PaymentProvider` di `types.ts`)
2. Daftar dalam `_shared/payments/index.ts`:
   ```ts
   import { fiuu } from './fiuu.ts'
   const PROVIDERS = { hitpay, fiuu }
   ```
3. Tukar secret: `supabase secrets set PAYMENT_PROVIDER=fiuu` (+ kunci Fiuu)
4. Re-deploy kedua-dua function

**TIDAK berubah:** `payment.html`, logik bisnes, skema DB, `payments-initiate`,
`payments-webhook`.

---

## 6) Auto-Caj Ansuran (kad tersimpan) — Recurring Billing on-demand

**Status: kod siap 23 Sept, BELUM migration/deploy/uji.** Sebelum ni HitPay cuma
checkout-link one-time (pesakit kena klik & bayar SETIAP ansuran). Kini pesakit
boleh **lampir kad SEKALI**, lepas tu tiap checkpoint ansuran seterusnya
**di-auto-caj sendiri** oleh cron pada tarikh due (jumlah BERBEZA setiap
checkpoint — bukan subscription/cycle tetap HitPay, guna endpoint on-demand
`POST /v1/charge/recurring-billing/{id}`).

**Fail terlibat:**
- `_shared/payments/types.ts` + `hitpay.ts` — `createCardAuthorization()`,
  `chargeSavedCard()`, `verifyRecurringWebhook()` (kontrak opsyenal baharu)
- `_shared/kob_autocharge.ts` — `createKobCardAttachLink()` (sesi lampir-kad BERDIRI
  SENDIRI, RM1) + `applyInstallmentPayment()` (logik kumulatif kongsi dgn `kob_installment_topup`)
- `_shared/kob_deposit_fulfill.ts` — `fulfillKobDeposit()` / `fulfillKobPackage()` +
  helper (`activatePackageForPatient` dll) diextract dari `payments-webhook` supaya
  BOLEH dipanggil dari DUA webhook (form-encoded biasa DAN JSON recurring)
- `payments-kob-initiate` — mode baharu `'attach_card'` (staff-only) + param
  `saveCard` pada mode `'installment'` (staff/pesakit pilih)
- `payments-webhook-recurring` (**fungsi BAHARU**) — webhook JSON `Hitpay-Signature`
  utk event `method_attached`/`method_detached`/`subscription_updated`
  (BEZA drpd `payments-webhook` form-encoded sedia ada)
- `event-reminders` — langkah baharu `runInstallmentAutoChargeCheck` (8b), jalan
  SEBELUM `installment_overdue`
- `roles/staff/kob-detail.html` — checkbox "Simpan kad" di Langkah 5 (deposit
  installment) + badge status kad & butang "Hantar Pautan Lampir Kad" (status paid)
- `database/schema/09_kob.sql` + `18_notifications_automations.sql` (sumber kebenaran)
- `supabase/migrations/20260923_installment_autocharge.sql` (utk DB sedia ada)

**Reka bentuk akhir (23 Sept, lepas bincang dgn management) — DUA cara lampir kad:**
1. **Serentak dgn deposit** (utama) — di Langkah 5 kob-detail.html, checkbox
   "Simpan kad" (default ON) utk mode Installment. DITANDA → deposit dibayar
   MELALUI recurring-billing (kad SAHAJA ditawar, FPX/e-wallet TIADA — had
   HitPay, tak boleh simpan kad drpd sesi FPX), kad terus tersimpan serentak
   dgn deposit — TIADA RM1 berasingan. NYAHTANDA → deposit macam biasa
   (semua kaedah termasuk FPX), ansuran seterusnya kekal manual.
2. **Berdiri sendiri (fallback)** — `createKobCardAttachLink` (RM1 pengesahan),
   utk pesakit yang deposit-nya sudah dibayar FPX/manual tapi kemudian nak
   join auto-caj. Butang "Hantar Pautan Lampir Kad" di kob-detail.html
   (status partial) guna laluan ni.

**Langkah sebelum live:**
1. Jalankan `supabase/migrations/20260923_installment_autocharge.sql` — TESTING dulu, PROD kemudian.
2. **Sahkan dgn HitPay support akaun aktifkan ciri "Recurring Billing"** (bukan semua akaun on by default).
3. Daftar webhook BAHARU di HitPay Dashboard → Developers → Webhook Endpoints:
   `https://<project>.supabase.co/functions/v1/payments-webhook-recurring`
   (event: `recurring_billing.method_attached`, `method_detached`, `subscription_updated`)
   — ASING drpd webhook `payments-webhook` sedia ada (payment-requests).
4. Deploy: `supabase functions deploy payments-webhook-recurring --no-verify-jwt`,
   `supabase functions deploy payments-kob-initiate`, `supabase functions deploy event-reminders`,
   `supabase functions deploy payments-webhook`.
5. **Uji di SANDBOX dulu — WAJIB sebelum prod**: sahkan checkout "deposit +
   simpan kad" (amount=deposit sebenar, bukan RM1) betul-betul **serah duit**
   tu kat ISW sebagai bayaran sah (bukan sekadar tokenize kad tanpa duit
   bergerak) — ini TAK disahkan dari dokumentasi awam HitPay, kena test
   transaksi sebenar di sandbox. Kalau tak settle sbg bayaran, deposit
   pesakit akan "hilang" (kad tersimpan tapi duit tak sampai).
6. Aktifkan templat WA (`is_active=true`) di UI Automatic Messages bila sedia:
   `card_attach_invite`, `installment_autocharge_success`, `installment_autocharge_failed`.
7. **dashboard-paste/**: fail `payments-webhook.ts`, `payments-initiate.ts` di situ
   ialah bundle flattened (deploy via paste Supabase Studio) — kalau staff pakai
   kaedah ni (bukan CLI), fail bundle BERKAITAN (`payments-webhook`,
   `payments-kob-initiate`, + `payments-webhook-recurring` baharu) perlu
   di-generate semula sebelum paste (tiada skrip build ditemui dlm repo — perlu
   disahkan macam mana bundle asal dijana).

## Nota keselamatan / hardening

- ✅ **Harga disahkan server-side** dalam `payments-initiate` (`verifiedAmount`) —
  pakej & produk disemak semula dari DB, client tak boleh usik amaun.
- ✅ **Webhook HMAC** — tolak panggilan palsu.
- ✅ **Semak silang amaun** dalam webhook (toleransi 1 sen).
- ✅ **Idempotent** — webhook boleh cetus berkali; guard `status='completed'` elak double-fulfill.
- ⚠️ **Jenis `appointment` / `plan_extension` / `kob`** masih guna amaun DB-derived dari client
  (bukan revenue tinggi). Boleh diperketat kemudian.
- 🔒 SST masih 0 — aktifkan bila syarikat daftar SST.


---


# ===== SQL_Accounting_Integration.md =====

# Integrasi SQL Accounting ⇄ ISW (Manual Trigger Sync)

> Sumber: one-pager asal "SQL Account → Supabase Sync (Manual Trigger)"
> bertarikh **9 Julai 2026**, status asal "For discussion". Digabung
> dengan pecahan 11-step & senarai komponen yang disediakan sama sesi.
> Status semasa (26 Ogos 2026): **belum mula coding**, masih peringkat
> requirement gathering — lihat Bahagian 8.

## 1. Objektif

Jadikan data kewangan SQL Accounting (On-Premise) boleh dicapai
**24/7** — walaupun PC/server On-Premise cuma hidup semasa waktu
pejabat — dengan cara **mirror** dataset kewangan penuh ke Supabase
secara **manual-triggered** (bukan auto/scheduled).

## 2. Setup semasa

- SQL Account jalan **On-Premise** pada PC dedicated. **Tiada rancangan
  upgrade ke SQL Account Cloud.**
- SQL Account API Service sudah enabled pada PC tu (port-forwarded,
  auth **AWS SigV4** via Access Key + Secret Key).
- PC & API **hanya online semasa waktu pejabat** — ini **boleh
  diterima** kerana tiada keperluan sync/panggilan selepas waktu
  pejabat.

## 3. Penyelesaian dicadangkan — kenapa Manual Trigger (bukan auto-sync)

Berbanding cron/scheduled sync yang perlukan PC on 24/7, pendekatan
ni:

1. Accountant **finalize** kemasukan hari tu dalam SQL Account
   (On-Premise).
2. Accountant klik **satu butang "Sync to Supabase"** (tool/shortcut
   ringkas dalam PC yang sama).
3. Script authenticate ke SQL Account API Service (AWS SigV4,
   Access+Secret Key, HTTPS port 443).
4. Script tarik (pull) dataset kewangan penuh melalui API.
5. Script transform/normalize rekod supaya match schema Supabase.
6. Script **upsert** ke Supabase, keyed pada ID stabil (**DocNo /
   dtlkey**) — selamat run berulang kali, tiada duplicate.
7. Setiap run di-log (timestamp, jumlah rekod, success/fail) + medan
   **"Last synced"** dikemaskini.
8. App/dashboard downstream **baca dari Supabase sahaja** — available
   24/7 tanpa kira status PC On-Premise.

Kelebihan: app/dashboard tak perlu bergantung PC On-Premise sentiasa
hidup — cukup accountant klik sync sekali sehari lepas books
finalized.

## 4. Data scope (dataset kewangan PENUH — bukan sebahagian)

Semua yang SQL Account API expose:

- Sales Invoices & Purchase Invoices
- Customer Payments & Supplier Payments
- GL (General Ledger) entries
- Rekod Customer & Supplier
- Stock Items

## 5. Arkitektur

```
INTERNET
   │
   ▼
Dedicated PC / Local Server
   SQL Accounting API Service
   │  (SQL Account API — AWS SigV4, port 443)
   ▼
Sync Service (Node.js / Python)
   pull → transform → upsert
   │
   ▼
Supabase
   Finance Data (schema berasingan)
```

**Point penting:** PC/server tu perlu **ON + internet available**
semasa sync dijalankan sahaja (bukan 24/7) — sebab trigger manual,
bukan scheduled.

## 6. Keselamatan & kawalan akses

- Butang sync **hanya untuk role accountant / authorized** — sebab ia
  effectively "publish" angka rasmi.
- Access Key & Secret Key SQL Account disimpan dalam secrets
  manager/env var pada PC — **jangan hardcode**.
- Supabase **service-role key** guna server-side sahaja dalam sync
  script — **jangan expose client-side**.
- **Row Level Security (RLS)** enabled pada mana-mana jadual Supabase
  yang dibaca oleh front-end/dashboard.
- Semua traffic encrypted in transit (HTTPS/TLS) — kedua-dua leg SQL
  Account API dan Supabase.
- Setiap sync run di-log untuk audit: siapa trigger, bila, jumlah
  rekod, outcome.

## 7. Risiko & mitigasi

| Risiko | Mitigasi |
|---|---|
| **Stale data** — Supabase cuma refleksi klik terakhir | Papar timestamp **"Last synced"** dengan jelas di mana-mana data tu digunakan |
| **Missed click** — accountant lupa sync | Tambah reminder hujung hari (end-of-day) supaya accountant tak lupa |
| **PC mesti ON untuk sync** | Sudah compatible dengan setup sedia ada (office-hours-only) |

## 8. 11-Step Rollout

| # | Step | Apa yang dibuat | Apa yang diperlukan |
|---|------|------------------|----------------------|
| 1 | Confirm SQL Account setup | Semak versi & database SQL Accounting | SQL Account + database |
| 2 | Prepare dedicated PC/server | PC yang menjalankan SQL Accounting/API | Windows PC/server |
| 3 | Enable SQL Account API Service | Install & configure API Service | SQL Account API Service |
| 4 | Create API credentials | Create API user & generate credentials | Access Key + Secret Key |
| 5 | Prepare network access | Pastikan API boleh dicapai | Stable Internet + Public IP + Port 443/port forwarding |
| 6 | Test API connection | Pastikan system boleh connect ke SQL Accounting | Postman / API testing tool |
| 7 | Confirm data scope | Tentukan data yang perlu diambil | Customer, Supplier, Invoice, Payment, GL, Stock dll. |
| 8 | Prepare Supabase | Sediakan database untuk financial data | Supabase project/schema + tables |
| 9 | Build sync service | Pull → transform → upsert | Backend/Node.js/Python + Supabase |
| 10 | UAT | Compare data dengan accountant | Test data + accountant validation |
| 11 | Go-live | Gunakan sync sebenar | Production credentials + monitoring/logging |

**Status:** baru di **Step 1** (verify SQL Account setup) — belum
disahkan oleh accountant/vendor.

## 9. Komponen/barang yang diperlukan

**SQL Accounting side:**
- SQL Accounting On-Premise
- Dedicated Windows PC/server
- SQL Account API Service
- API User
- Access Key
- Secret Key
- Stable Internet
- Public IP
- Port 443 / port forwarding

**Development side:**
- Backend/server untuk sync script
- Supabase (cadang plan **Pro**, ~US$25/bulan + usage — free tier
  **tak sesuai**: had 500MB, auto-pause selepas 7 hari idle, tak
  sesuai untuk "full financial dataset" + keperluan reliability harian)
- Postman untuk testing API
- Database schema/table untuk finance
- Logging mechanism

**People/access:**
- Accountant — untuk validate data & trigger sync
- IT/network person — untuk public IP & port forwarding
- Developer — untuk API + Supabase integration

## 10. Cost & anggaran masa (kasar, developer perlu confirm ikut kapasiti sebenar)

| Item | Anggaran |
|---|---|
| SQL Account | Tiada perubahan — kekal On-Premise, tiada fee upgrade Cloud |
| Supabase plan | Pro, ~US$25/bulan + usage |
| Dev effort | One-time build: schema + sync script + trigger UI + logging |

**Rough phasing:**
- Confirm API version/keys sudah enabled — segera
- Design schema Supabase untuk dataset kewangan penuh — beberapa hari
- Build sync script (pull → transform → upsert) + logging — ~1 minggu
- Build trigger button/UI + access control — 2-3 hari
- UAT dengan accountant, validate angka vs SQL Account, go-live —
  beberapa hari

## 11. Checklist keperluan minimum (untuk hantar kat accountant/vendor)

| # | Item | Status |
|---|------|--------|
| 1 | Versi SQL Account (minimum 5.2025.1038.875+) & Firebird (3.0.9+) | ⬜ belum disahkan |
| 2 | API Service enabled pada instalasi tu | ⬜ belum disahkan |
| 3 | PC/server dedicated mana yang jadi API host | ⬜ belum ditentukan |
| 4 | Public IP + port forwarding port 443 sudah setup | ⬜ belum |
| 5 | User API khas (APIUser) + Access Key/Secret Key sudah generate | ⬜ belum |
| 6 | Data scope disahkan (rujuk Bahagian 4 — dataset penuh) | ✅ sudah confirm dalam one-pager asal |
| 7 | Arah sync (SQL Account → Supabase sahaja, one-way) | ✅ sudah confirm — one-way, manual trigger |
| 8 | Frekuensi sync (manual, on-demand oleh accountant) | ✅ sudah confirm — bukan real-time/scheduled |

## 12. Langkah seterusnya untuk developer

1. Confirm versi/setup SQL Account API memenuhi keperluan (dah
   configured On-Premise ke belum).
2. Finalize senarai field/entity tepat untuk "dataset kewangan penuh".
3. Provision Supabase project (Pro plan) + design schema mirror.
4. Build & test sync script + trigger button end-to-end bersama
   accountant.

## 13. Nota

- Ini **belum ada kod/migration** dibina — dokumen ni pelan sahaja.
- Sync **satu hala** (SQL Account → Supabase); tiada tulis balik ke
  SQL Account dari ISW.
- Kalau kelak keperluan berubah (cth. perlu near-real-time atau
  dua-hala), kena re-evaluate arkitektur "manual trigger" ni — bukan
  reka sekarang untuk kes yang belum pasti berlaku.


---


# ===== Sync_GHL_ISW.md =====

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
                                       ├─► GET /payments/transactions?contactId= (tapis succeeded/paid/completed)
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

**Syarat masuk tambahan (11-12 Ogos 2026):** status relevan sahaja TAK
MEMADAI — contact mesti JUGA ada (a) sekurang-kurangnya 1 appointment
pada salah satu **6 kalendar KOB tapak** (`KONSULTASI OVERHAUL BODY
[WC1]` hingga `[WC5]` + `[EG]`) DAN (b) sekurang-kurangnya 1 **GHL
Transaction** succeeded/paid/completed. Akaun sebenarnya ada 10 kalendar
mengandungi "KONSULTASI OVERHAUL BODY" (54 kalendar keseluruhan) — 4
daripadanya ("KOB VIP"/"VIP 2/3/4") **sengaja dikecualikan** (keputusan
user, bukan slot tapak biasa). Padanan kod: `isKobCalendarName()` —
includes nama DAN NOT includes "VIP".

**Kenapa Transaction, bukan Order:** disahkan 12 Ogos 2026 — kebanyakan
yuran KOB akaun ni dibayar **transfer manual**, staff tandakan **Invoice**
GHL "paid" (Text2Pay dll), objek **berasingan** dari Order/checkout, TAK
muncul dalam `/payments/orders` langsung (nisbah lulus naik 1/9 → 5/9
sampel selepas fix). `/payments/transactions` = **ledger bersepadu**
rasmi GHL, tangkap Order+Invoice+Stripe+Manual SEKALI GUS status seragam
— jadi cukup 1 semakan, tak perlu Order & Invoice berasingan.

Belum ada kedua-dua syarat → diskip, TAK dicipta dalam `psy_patients`
lagi (cuba lagi run seterusnya). Lihat §Filter dalam `README.md` sebelah
`ghl-pull-sync/index.ts` untuk cara sahkan nama kalendar
(`{debug:true,action:'list_calendars'}`) atau siasat contact tertentu
(`{debug:true,action:'diagnose_gate'}`).

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
| Transaction succeeded/paid/completed | (`GET /payments/transactions`) | `psy_payments.total` + `ghl_transaction_id` |

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

## Status semasa (12 Ogos 2026)

**GHL → ISW (`ghl-pull-sync`):**
- ✅ Fungsi dibina, dideploy ke **testing** (`ipmemyizigwgivccytcu`) sahaja
- ✅ Diuji end-to-end (contact, appointment, payment, IC/alamat/waris)
- ✅ Cleanup sekali sahaja: 698 pesakit (CANCEL/NO SHOW/KIV) di-soft-delete
- ✅ 662 nama dipulihkan ke bentuk asal GHL (lepas keputusan "jangan bersih nama")
- ✅ **Syarat masuk payment+booking (11-12 Ogos) DISAHKAN JALAN**: kalendar
  KOB (`KONSULTASI OVERHAUL BODY [WC1..5]`/`[EG]`, 6 daripada 10 padan,
  4 "VIP" dikecualikan) + Transaction succeeded/paid/completed (guna
  `/payments/transactions`, ledger bersepadu — BUKAN `/payments/orders`
  sahaja, sebab kebanyakan yuran dibayar manual via Invoice GHL yang tak
  muncul dlm Orders). Diuji **pusingan PENUH akaun** (~7,925 contact,
  beberapa kali ulang semasa dev) — `errorCount:0` konsisten setiap run,
  `reachedEnd:true` tercapai. Debug action `diagnose_gate` + `list_calendars`
  tersedia untuk troubleshoot lanjut.
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

## Ledger Rekonsiliasi Kewangan — `ghl-transactions-sync` (17 Sept 2026)

Berasingan dari `ghl-pull-sync` (yang isi `psy_payments` untuk gate KOB
sahaja) — fungsi ni tarik **SEMUA** transaksi bayaran lokasi GHL (Stripe
+ manual/invoice sekali gus, endpoint `/payments/transactions`) ke
jadual raw `psy_ghl_transactions`, untuk **reconciliation kewangan**
(halaman staff **"Payment Management"**, `roles/staff/payment-ledger.html`
— lihat juga `vw_payment_ledger`, VIEW gabungan `psy_payments`+
`psy_ghl_transactions` yang halaman ni baca).

**TIADA akses Stripe secret diperlukan** — GHL embed objek Stripe PENUH
(payment_intent+charge) dalam `chargeSnapshot` untuk transaksi
`paymentProviderType==='stripe'`, jadi `GHL_ISW_TOKEN` sahaja dah cukup.

### Field yang ditarik → kolum `psy_ghl_transactions`

| Kolum DB | Field GHL (`t.*`) | Nota |
|---|---|---|
| `ghl_transaction_id` | `_id` | Unique key, guna untuk upsert idempotent |
| `contact_id` | `contactId` | |
| `contact_name` | `contactName` | |
| `contact_email` | `contactEmail` | |
| `patient_id` | *(derived)* | Padan ke `psy_patients` ikut email sahaja, best-effort — NULL kalau tak jumpa (transaksi GHL tak bawa phone terus) |
| `amount` | `amount` | RM (unit manusia — GHL top-level BUKAN sen, beza dari `chargeSnapshot` dalaman Stripe yang guna sen) |
| `amount_refunded` | `amountRefunded` | |
| `currency` | `currency` | |
| `status` | `status` | Mentah GHL — **cuma `succeeded` yang disimpan** (lihat §Tapisan) |
| `payment_provider_type` | `paymentProviderType` | `'stripe'` \| `'manual'` |
| `entity_type` | `entityType` | `'order'` \| `'invoice'` |
| `entity_source_type` | `entitySourceType` | cth `'payment_link'`, `'text2Pay'` |
| `entity_source_name` | `entitySourceName` | Nama produk/invois |
| `entity_id` | `entityId` | ID invois/order asal |
| `charge_id` | `t.chargeId` / `chargeSnapshot.id` | Stripe `payment_intent` id (`pi_...`) — stripe sahaja, untuk lookup Stripe API terus di masa depan (Laluan B) kalau perlu fee/net/payout |
| `payment_method_type` | `chargeSnapshot.charges.data[0].payment_method_details.type` (stripe) / `chargeSnapshot.mode` (manual) | cth `'fpx'`/`'card'`/`'bank_transfer'` |
| `receipt_url` | `chargeSnapshot.charges.data[0].receipt_url` | Resit RASMI Stripe — stripe sahaja |
| `invoice_number` | `entitySourceMeta.invoiceNumberPrefix`+`invoiceNumber` | cth "INV-000952" — entityType='invoice' sahaja |
| `issue_date` | `GET /invoices/` (panggilan BERASINGAN, ikut `contactId`, padan `_id`==`entityId`) `.issueDate` | **BEZA** dari `ghl_created_at` (bila bayaran DIREKOD, bukan bila invois DIISUKAN) — disahkan boleh beza sehingga >1 minggu |
| `live_mode` | `liveMode` | Lihat §Tapisan |
| `ghl_created_at` | `createdAt` | |
| `ghl_updated_at` | `updatedAt` | |
| `fulfilled_at` | `fulfilledAt` | |
| `raw` | *(objek `t` PENUH)* | Safety net — field yang terlepas senarai atas masih boleh diquery dari sini |

### Tapisan (buang SEBELUM simpan — keputusan user 17 Sept 2026)

Rekod dibuang (tak disimpan langsung) kalau PADAN MANA-MANA syarat ni:

| Field | Syarat buang |
|---|---|
| `status` | Bukan `"succeeded"` tepat |
| `liveMode` | Bukan `true` (test-mode Stripe — **48/190 (25%) rekod awal!**) |
| `contactName` | Mengandungi "test" (case-insensitive) |
| `contactEmail` | Mengandungi "test" (case-insensitive) |
| `entitySourceName` | Mengandungi "test" (case-insensitive) |

(Nota: exact-match "Najihah Megat Salim" pernah ditambah sekali-guna
untuk 1 rekod test lama, **kemudian DIBUANG** (17 Sept 2026) sebab bukan
peraturan kekal — elak sekat pesakit sebenar nama sama akan datang.)

**Disahkan 17 Sept 2026** — hasil akhir (38 rekod) dibanding baris-demi-baris
dengan senarai rujukan manual, **100% padan sempurna** (tiada tertinggal,
tiada lebih).

### Status (17 Sept 2026)

- ✅ Dibina + diuji, **DIJADUALKAN pg_cron setiap 30 minit** (testing
  sahaja, `ipmemyizigwgivccytcu`, jobid 8)
- ✅ Halaman staff `payment-ledger.html` ("Payment Management") — gabung
  `psy_payments`+`psy_ghl_transactions` via `vw_payment_ledger`, dedup
  ikut `ghl_transaction_id` (elak double-count dgn rekod yang `ghl-pull-sync`
  dah sync), pagination 10/muka surat, filter (sumber/status/tempoh/carian),
  export CSV
- ⏳ **Belum deploy ke production**

## Nota sejarah (kenapa bukan webhook)

Cubaan awal guna 3 GHL Workflow (Appointment/Order/Contact → webhook
`ghl-booking-webhook`) menemui banyak halangan: merge field GHL format
tak konsisten (masa "1530" tanpa titik dua, custom field ID tanpa
key/name), dan "Test workflow" GHL didapati tak simulasi konteks
appointment sebenar (sentiasa gagal walaupun konfigurasi betul). Fungsi
`ghl-booking-webhook` kekal deployed (harmless) tapi digantikan
sepenuhnya oleh pendekatan pull (`ghl-pull-sync`) — data terus dari
JSON API, tiada isu merge-tag.


---
