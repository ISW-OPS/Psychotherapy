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
