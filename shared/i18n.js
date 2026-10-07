/* ============================================================
   ISW i18n — bilingual (BM ⇄ EN) engine + shared glossary.
   ─ Approach: most source text in HTML is Malay (BM) — picking
     English swaps it via the EN glossary below. Some UI text was
     authored directly in English instead; picking BM swaps THAT
     via the MS glossary (shared/i18n-dict-ms.js). Either way,
     whatever isn't in the matching dict simply stays as-authored.
   ─ Persistence: choice saved in localStorage('isw_lang').
   ─ Coverage: text nodes + placeholder/title/aria-label attrs,
     plus dynamically-added content (navbar, topbar, lists…) via
     a MutationObserver.
   ─ Default language: EN (per product decision).
   Idempotent & safe to load on every page.
   ============================================================ */
(function () {
  if (window.__iswI18n) return;
  window.__iswI18n = true;

  var DEFAULT_LANG = 'en';
  var STORE = 'isw_lang';

  function getLang() { return localStorage.getItem(STORE) || DEFAULT_LANG; }

  // ── Glossary: Malay source (trimmed) → English ──────────────
  // Grows incrementally. Common UI terms translate everywhere once added.
  var EN = {
    // — Promo & Voucher staff pages (promo-codes / promo-detail / promo-redemptions / promo-vouchers) — added 6 Okt —
    "Kod Promo": "Promo Codes",
    "Penggunaan Promosi": "Promo Usage",
    "Penggunaan promosi": "Promo usage",
    "Voucher Pesakit": "Patient Vouchers",
    "Voucher pesakit": "Patient vouchers",
    "Butiran Promosi": "Promo Details",
    "Butiran promosi": "Promo details",
    "Kod diskaun untuk Shop dan pakej. Pesakit taip kod di cart sebelum bayar.": "Discount codes for Shop and packages. Patients enter the code in the cart before paying.",
    "Voucher yang dikeluarkan kepada pesakit. Boleh dikeluarkan secara manual, atau datang dari ganjaran mata & rujukan.": "Vouchers issued to patients. Can be issued manually, or come from point rewards & referrals.",
    "Semua penggunaan kod promo merentas pesanan, termasuk jumlah diskaun yang diberi.": "All promo code redemptions across orders, including total discount given.",
    "+ Cipta Promosi": "+ Create Promotion",
    "Cipta Promosi": "Create Promotion",
    "Edit Promosi": "Edit Promotion",
    "+ Keluarkan Voucher": "+ Issue Voucher",
    "Keluarkan Voucher": "Issue Voucher",
    "Jumlah Promosi": "Total Promotions",
    "Jumlah Voucher": "Total Vouchers",
    "Jumlah Penggunaan": "Total Redemptions",
    "Jumlah Diskaun": "Total Discount",
    "Jumlah Diskaun Diberi": "Total Discount Given",
    "Pesakit Unik": "Unique Patients",
    "Luput / Batal": "Expired / Cancelled",
    "Semua": "All",
    "Tidak Aktif": "Inactive",
    "Dijadualkan": "Scheduled",
    "Habis Guna": "Fully Used",
    "Cari kod, nama atau penerangan…": "Search code, name or description…",
    "Cari kod voucher, nama pesakit atau MRN…": "Search voucher code, patient name or MRN…",
    "Cari pesakit, MRN, no. resit…": "Search patient, MRN, receipt no…",
    "Cari nama, MRN atau telefon pesakit…": "Search patient name, MRN or phone…",
    "Cari nama, MRN atau telefon…": "Search name, MRN or phone…",
    "Semua Jenis": "All Types",
    "Semua Skop": "All Scopes",
    "Semua Sumber": "All Sources",
    "Semua Kod": "All Codes",
    "Semua Status Bayaran": "All Payment Statuses",
    "Dari tarikh": "From date",
    "Hingga tarikh": "To date",
    "Peratus (%)": "Percentage (%)",
    "Tetap (RM)": "Fixed Amount (RM)",
    "Kod / Nama": "Code / Name",
    "Jenis": "Type",
    "Jenis Diskaun": "Discount Type",
    "Diskaun": "Discount",
    "Nilai": "Value",
    "Nilai (RM)": "Value (RM)",
    "Nilai Diskaun": "Discount Value",
    "Had Maksimum Diskaun (RM)": "Maximum Discount Cap (RM)",
    "Had Maksimum Diskaun": "Maximum Discount Cap",
    "Had maksimum hanya guna untuk diskaun peratus. Contoh: 10% max RM100.": "The cap only applies to percentage discounts. Example: 10% max RM100.",
    "Terpakai Untuk": "Applicable To",
    "Kod hanya sah jika troli ADA item ini. Diskaun tetap dikira atas seluruh subjumlah troli.": "The code is only valid if the cart HAS this item. Fixed discounts apply to the whole cart subtotal.",
    "Kelayakan": "Eligibility",
    "Pelanggan Layak": "Eligible Customers",
    "Semua Pesakit": "All Patients",
    "Pesakit Baharu Sahaja (belum pernah bayar)": "New Patients Only (never paid)",
    "Pesakit Sedia Ada Sahaja (pernah bayar)": "Existing Patients Only (has paid before)",
    "Pesakit Tertentu": "Selected Patients",
    "Pesakit baharu": "New patients",
    "Pesakit sedia ada": "Existing patients",
    "Pesakit tertentu": "Selected patients",
    "Pelanggan baharu": "New customers",
    "Pelanggan sedia ada": "Existing customers",
    "Pelanggan Baharu": "New Customers",
    "Pelanggan Baharu Sahaja": "New Patients Only",
    "Pesakit Baharu Sahaja": "New Patients Only",
    "Pesakit Sedia Ada Sahaja": "Existing Patients Only",
    "Min. Belanja": "Min. Spend",
    "Min. Belanja (RM)": "Min. Spend (RM)",
    "Min. Subjumlah (RM)": "Min. Subtotal (RM)",
    "Bilangan Pesakit Dipilih": "Selected Patients Count",
    "Cari pesakit": "Search patient",
    "Had Penggunaan": "Usage Limits",
    "Had Keseluruhan": "Total Limit",
    "Had Setiap Pesakit": "Limit Per Patient",
    "Boleh gabung dengan promosi/baucar lain": "Can combine with other promotions/vouchers",
    "Boleh Gabung": "Can Combine",
    "Lalai: TIDAK. MVP: hanya satu promosi/baucar bagi setiap pesanan.": "Default: NO. MVP: only one promotion/voucher per order.",
    "Tidak (MVP: satu promosi/baucar setiap pesanan)": "No (MVP: one promotion/voucher per order)",
    "Tempoh Sah": "Validity Period",
    "Tarikh Mula": "Start Date",
    "Tarikh Tamat": "End Date",
    "Tarikh Luput": "Expiry Date",
    "Tarikh Guna": "Used Date",
    "Tarikh": "Date",
    "Status automatik: sebelum mula = Dijadualkan · dalam tempoh = Aktif · lepas tamat = Luput · had habis = Habis Guna.": "Automatic status: before start = Scheduled · within period = Active · after end = Expired · limit reached = Fully Used.",
    "Paparan & Status": "Display & Status",
    "Papar dalam banner Shop pesakit": "Show in patient Shop banner",
    "Papar Dalam Banner Shop": "Show in Shop Banner",
    "Maklumat Asas": "Basic Information",
    "Nama Promosi": "Promotion Name",
    "Nama Voucher": "Voucher Name",
    "Nama": "Name",
    "Penerangan (pilihan)": "Description (optional)",
    "Kempen (pilihan, untuk laporan)": "Campaign (optional, for reports)",
    "Kempen": "Campaign",
    "Catatan (pilihan)": "Note (optional)",
    "Kod Voucher": "Voucher Code",
    "Kod": "Code",
    "Penggunaan Promo": "Promo Usage",
    "Ibnu Sina Wellness — Cipta Promosi": "Ibnu Sina Wellness — Create Promotion",
    "Cipta / edit promosi": "Create / edit promotion",
    "Tetapkan kod promosi dengan peraturan dan syarat tertentu.": "Set up a promo code with specific rules and conditions.",
    "Nama dalaman untuk kenal pasti promosi ini.": "Internal name to identify this promotion.",
    "Jana": "Generate",
    "Kod yang dimasukkan pesakit di cart.": "Code entered by the patient in the cart.",
    "Jenis Promosi": "Promotion Type",
    "Dimasukkan pesakit di checkout.": "Entered by the patient at checkout.",
    "Dikeluarkan ke dompet pesakit. Guna halaman Voucher Pesakit.": "Issued to the patient's wallet. Use the Patient Vouchers page.",
    "Had Maksimum (pilihan)": "Maximum Cap (optional)",
    "Had maksimum setiap pesanan. Untuk peratus sahaja.": "Maximum discount per order. Percentage only.",
    "Terpakai Untuk & Kelayakan": "Applicable To & Eligibility",
    "Terpakai Untuk &amp; Kelayakan": "Applicable To & Eligibility",
    "Kelayakan Pelanggan": "Customer Eligibility",
    "Kempen (pilihan)": "Campaign (optional)",
    "penggunaan": "redemptions",
    "1 kali setiap pesakit": "1 time per patient",
    "Tanpa had": "No limit",
    "2 kali setiap pesakit": "2 times per patient",
    "3 kali setiap pesakit": "3 times per patient",
    "Boleh digabung dengan promosi lain?": "Can be combined with other promotions?",
    "Ya (lalai: Tidak)": "Yes (default: No)",
    "Jika Tidak: hanya satu promosi atau baucar boleh digunakan setiap pesanan (dasar MVP).": "If No: only one promotion or voucher can be used per order (MVP policy).",
    "Sah sehingga 11:59 malam pada tarikh tamat. Masa mula/tamat tidak disimpan lagi.": "Valid until 11:59 PM on the end date. Start/end times are not stored yet.",
    "Tetapan Tambahan": "Additional Settings",
    "Status Dijadualkan, Luput dan Habis Guna dikira automatik mengikut tarikh dan had.": "Scheduled, Expired and Fully Used statuses are calculated automatically from dates and limits.",
    "Hantar notifikasi kepada pesakit layak": "Send notification to eligible patients",
    "(belum tersedia)": "(not yet available)",
    "Pratonton Promosi": "Promotion Preview",
    "Untuk semua pesakit": "For all patients",
    "Guna kod": "Use code",
    "Tiada min. belanja": "No min. spend",
    "Min. belanja": "Min. spend",
    "Sah": "Valid",
    "hingga": "until",
    "Tiada tempoh": "No period",
    "Tiada padanan": "No matches",
    "Belum ada item dipilih": "No items selected yet",
    "item dipilih": "items selected",
    "dipilih": "selected",
    "Semua pesakit": "All patients",
    "Pesakit baharu sahaja": "New patients only",
    "Pesakit sedia ada sahaja": "Existing patients only",
    "pesakit tertentu": "selected patients",
    "Produk tertentu": "Selected products",
    "Kategori tertentu": "Selected categories",
    "Pakej tertentu": "Selected packages",
    "Tiada had": "No limit",
    "Had keseluruhan": "Total limit",
    "Had setiap pesakit": "Limit per patient",
    "Boleh gabung": "Can combine",
    "Tempoh": "Period",
    "Banner Shop": "Shop banner",
    "Terpakai untuk": "Applicable to",
    "Kelayakan": "Eligibility",
    "Tarikh tamat mesti selepas tarikh mula": "End date must be after start date",
    "Simpan Perubahan": "Save Changes",
    "Cari…": "Search…",
    "cth: New Patient 10% Off": "e.g. New Patient 10% Off",
    "cth: Diskaun 10% untuk pembelian pertama": "e.g. 10% discount for first purchase",
    "cth: Raya 2026": "e.g. Raya 2026",
    "Cipta dan urus kod promosi untuk produk dan pakej Shop.": "Create and manage promo codes for Shop products and packages.",
    "Status": "Status",
    "Voucher": "Voucher",
    "Had Maksimum Diskaun (pilihan)": "Maximum Discount Cap (optional)",
    "RM": "RM",
    "Kelayakan & Terpakai Untuk": "Eligibility & Applicable To",
    "Item Dipilih (0)": "Selected Items (0)",
    "Item Dipilih": "Selected Items",
    "Pesakit Dipilih (": "Selected Patients (",
    "Pesakit Dipilih": "Selected Patients",
    "Had Keseluruhan Penebusan": "Total Redemption Limit",
    "Jumlah kali kod ini boleh digunakan.": "Total number of times this code can be used.",
    "Tidak (hanya satu promosi setiap pesanan)": "No (only one promotion per order)",
    "Ya (boleh gabung)": "Yes (can combine)",
    "Lalai: Tidak. Dasar MVP: satu promosi atau baucar setiap pesanan.": "Default: No. MVP policy: one promotion or voucher per order.",
    "Masa tetap: 12:00 AM hingga 11:59 PM. Masa tersuai belum disokong.": "Fixed times: 12:00 AM to 11:59 PM. Custom times are not supported yet.",
    "Dijadualkan, Luput dan Habis Guna dikira automatik.": "Scheduled, Expired and Fully Used are calculated automatically.",
    "BARU": "NEW",
    "← Kembali ke Kod Promo": "← Back to Promo Codes",
    "⧉ Duplikat": "⧉ Duplicate",
    "Ikhtisar": "Overview",
    "Peraturan & Syarat": "Rules & Conditions",
    "Butiran Penggunaan": "Redemption Details",
    "Pilih satu penggunaan untuk lihat butiran.": "Select a redemption to view details.",
    "⬇ Eksport": "⬇ Export",
    "Bayaran Selesai": "Completed Payments",
    "Menunggu Bayaran": "Pending Payments",
    "RM 0.00": "RM 0.00",
    "Semua Kod Promo": "All Promo Codes",
    "No. Pesanan": "Order No.",
    "Jumlah Asal": "Order Amount",
    "Jumlah Akhir": "Final Amount",
    "Cari pesakit, MRN, no. resit…": "Search patient, MRN, receipt no…",
    "Pilih voucher untuk lihat butiran.": "Select a voucher to view details.",
    "Luput / Dibatalkan": "Expired / Cancelled",
    "Butiran Voucher": "Voucher Details",
    "Lanjut Tempoh Sah": "Extend Validity Period",
    "Cari kod voucher, nama atau pesakit…": "Search voucher code, name or patient…",
    "cth: Birthday Reward": "e.g. Birthday Reward",
    "cth: Pampasan kelewatan penghantaran": "e.g. Compensation for delivery delay",
    "Semua Kod Promo": "All Promo Codes",
    "Had Maks (pilihan) ⓘ": "Max Cap (optional) ⓘ",
    "Pesakit taip atau claim kod sendiri di checkout / My Vouchers.": "Patient types or claims the code themselves at checkout / My Vouchers.",
    "Terus masuk My Vouchers pesakit layak secara automatik sebaik sahaja promosi ini Aktif.": "Goes straight into eligible patients' My Vouchers automatically as soon as this promotion is Active.",
    "Hantar ke Pesakit": "Send to Patients",
    "🎁 Hantar ke Pesakit": "🎁 Send to Patients",
    "Promosi ini jenis Voucher. Ia akan dihantar terus ke My Vouchers pesakit layak, bukan sebagai kod yang perlu ditaip.": "This promotion is a Voucher. It will be sent straight to eligible patients' My Vouchers, not as a code to type.",
    "Akan dihantar kepada": "Will be sent to",
    "pesakit layak yang belum menerimanya. Teruskan?": "eligible patients who have not received it yet. Continue?",
    "Semua pesakit layak sudah menerima voucher ini.": "All eligible patients have already received this voucher.",
    "Voucher dihantar kepada": "Voucher sent to",
    "pesakit ✅": "patients ✅",
    "Menghantar…": "Sending…",
    "Dicipta oleh": "Created by",
    "Diskaun & Kempen": "Discount & Campaign",
    "Terhad kepada": "Limited to",
    "Tidak terhad": "Unlimited",
    "Lalai: 12:00 AM hingga 11:59 PM. Boleh tukar masa mula dan tamat.": "Default: 12:00 AM to 11:59 PM. Start and end times can be changed.",
    "Tiada": "None",
    "Simpan Draf": "Save Draft",
    "Lihat senarai penggunaan": "View redemption list",
    "Tapis: bayaran selesai sahaja": "Filter: completed payments only",
    "Cari pesakit": "Search patient",
    "Semua Produk": "All Products",
    "Produk Tertentu": "Selected Products",
    "Kategori Tertentu": "Selected Categories",
    "Pakej Tertentu": "Selected Packages",
    "Tiada promosi dalam senarai ini": "No promotions in this list",
    "Ibnu Sina Wellness — Butiran Promosi": "Ibnu Sina Wellness — Promo Details",
    "Ibnu Sina Wellness — Penggunaan Promosi": "Ibnu Sina Wellness — Promo Usage",
    "Ibnu Sina Wellness — Voucher Pesakit": "Ibnu Sina Wellness — Patient Vouchers",
    "Voucher Pesakit": "Patient Vouchers",
    "Simpan Promosi": "Save Promotion",
    "Simpan": "Save",
    "Batal": "Cancel",
    "Lanjut": "Extend",
    "Lanjut Tarikh Luput": "Extend Expiry Date",
    "Tanda Guna": "Mark Used",
    "Sumber": "Source",
    "Pesakit": "Patient",
    "Pelanggan": "Customer",
    "Nama Pesakit": "Patient Name",
    "No. Resit": "Receipt No.",
    "No Resit": "Receipt No.",
    "Diskaun (RM)": "Discount (RM)",
    "Status Bayaran": "Payment Status",
    "Selesai": "Completed",
    "Menunggu": "Pending",
    "Dibayar Balik": "Refunded",
    "Gagal": "Failed",
    "Dibatalkan": "Cancelled",
    "Digunakan": "Used",
    "Manual": "Manual",
    "Ganjaran Mata": "Point Rewards",
    "Rujukan": "Referral",
    "Kempen (campaign)": "Campaign",
    "Pampasan": "Compensation",
    "Item Terpakai": "Applicable Items",
    "Peraturan": "Rules",
    "Log Aktiviti": "Activity Log",
    "Tiada penggunaan dijumpai": "No redemptions found",
    "Belum ada penggunaan": "No redemptions yet",
    "Tiada log aktiviti": "No activity log",
    "Tiada item": "No items",
    "Tiada voucher dalam senarai ini": "No vouchers in this list",
    "Tiada padanan": "No matches",
    "Tiada pilihan tersedia": "No options available",
    "Belum ada pesakit dipilih": "No patient selected yet",
    "Memuatkan…": "Loading…",
    "Memuatkan...": "Loading...",
    "Promosi ini terpakai untuk": "This promotion applies to",
    "semua produk": "all products",
    "Lihat Promosi": "View Promotion",
    "Lihat": "View",
    "Eksport CSV": "Export CSV",
    "⬇ Eksport CSV": "⬇ Export CSV",
    "← Kembali": "← Back",
    "Kembali": "Back",
    "Promosi tidak dijumpai.": "Promotion not found.",
    "Maklumat Voucher": "Voucher Details",
    "Pesakit Tertentu sahaja": "Selected patients only",
    "Ringkasan": "Summary",
    "Sila pilih pesakit": "Please select a patient",
    "Dipilih:": "Selected:",
    "Tiada data untuk dieksport": "No data to export",
    "Tiada had": "No limit",
    "Had maksimum": "Maximum cap",
    "maks": "max",
    "Diskaun tetap": "Fixed discount",
    "Kod diskaun kedai": "Shop discount codes",
    "Voucher dikeluarkan ✅": "Voucher issued ✅",
    "Ibnu Sina Wellness — Kod Promo": "Ibnu Sina Wellness — Promo Codes",

    // — KOB staff wizard button labels (kob-detail.html) — added 22 Sept —
    "📋 Salin Pautan": "📋 Copy Link",
    // — KOB self-checkout pending-confirmation screen (kob.html) — added 22 Sept —
    "Menyemak Bayaran…": "Checking Payment…",
    "Menyemak Status Bayaran": "Checking Payment Status",
    "Sila selesaikan bayaran melalui invois di bawah.": "Please complete payment via the invoice below.",
    "Bayaran Belum Disahkan": "Payment Not Yet Confirmed",
    "Jika anda baru selesai bayar, sila tunggu seketika & muat semula halaman ini. Jika bayaran tidak dihabiskan, sila cuba bayar semula.": "If you just finished paying, please wait a moment and reload this page. If the payment wasn't completed, please try paying again.",
    "Cuba Bayar Semula": "Try Paying Again",
    // — Bayaran manual / invois / waris — added 21 Sept —
    "🧾 Sejarah Transaksi": "🧾 Transaction History",
    "📄 Lihat Invois": "📄 View Invoice",
    "🧾 Resit": "🧾 Receipt",
    "📎 Bukti": "📎 Proof",
    "📋 Link Payment": "📋 Payment Link",
    "🧾 Transaksi": "🧾 Transactions",
    "Ansuran yang dituntut (cth: Deposit / Ansuran 2)": "Installment being billed (e.g. Deposit / Installment 2)",
    "Jumlah ansuran yang perlu dibayar (RM)": "Installment amount to pay (RM)",
    "Baki yang perlu dibayar (RM)": "Balance to pay (RM)",
    "Tarikh ansuran jatuh tempoh": "Installment due date",
    "Pautan bayaran HitPay (turut melampirkan invois PDF) — hanya automasi Ansuran": "HitPay payment link (also attaches the PDF invoice) — Installment automations only",
    "📎 Lampirkan invois PDF": "📎 Attach invoice PDF",
    "Invois ansuran (Amount Due = ansuran itu sahaja, dengan butang Pay) dilampirkan bersama mesej ini. Teks mesej mesti ada {{pautan}}.": "The installment invoice (Amount Due = that installment only, with a Pay button) is attached to this message. The message text must contain {{pautan}}.",
    "Bayaran untuk": "Payment for",
    "Bank Reference": "Bank Reference",
    "(wajib untuk transfer)": "(required for transfer)",
    "Tarikh & Masa Bayaran": "Payment Date & Time",
    "Rekod Bayaran Manual": "Record Manual Payment",
    "— Pilih pesakit dahulu —": "— Select a patient first —",
    "Nama Item / Konsultasi": "Item Name / Consultation",
    "cth: no. transaksi / rujukan bank": "e.g. transaction no. / bank reference",
    "cth: Konsultasi Doktor / Madu 500g": "e.g. Doctor Consultation / Honey 500g",
    "🔁 Coach Ganti (sesi ini sahaja)": "🔁 Substitute Coach (this session only)",
    "Untuk sesi ini sahaja (cth coach asal MC/tidak hadir) — pesakit kekal di bawah coach utama.": "For this session only (e.g. original coach is on leave/absent) — the patient stays with the primary coach.",
    "📄 Invois": "📄 Invoice",
    "Cari no. resit (REC) / no. invois (INV) / rujukan / nama pesakit...": "Search receipt no. (REC) / invoice no. (INV) / reference / patient name...",
    "📎 Lihat Bukti": "📎 View Proof",
    "📄 Invois Ansuran": "📄 Installment Invoice",
    "📑 Invois Penuh": "📑 Full Plan Invoice",
    "Sejarah Transaksi": "Transaction History",
    "Tiada transaksi.": "No transactions.",
    "Tunai": "Cash",
    "Kaedah Bayaran": "Payment Method",
    "No. Rujukan (pilihan)": "Reference No. (optional)",
    "Upload Bukti Bayaran": "Upload Proof of Payment",
    "(wajib kecuali tunai)": "(required unless cash)",
    "💵 Bayar Manual": "💵 Pay Manually",
    "🧾 Lihat Invois": "🧾 View Invoice",
    "Diskaun (RM, pilihan)": "Discount (RM, optional)",
    "Dipaparkan di invois/resit. Harga pakej di atas sudah harga selepas diskaun.": "Shown on the invoice/receipt. The package price above is already the price after discount.",
    "Bayaran di KOB direkod sekali sahaja. Baki direkod di": "Payment at KOB is recorded once only. The balance is recorded in",
    "(tab Bayaran).": "(Payments tab).",
    "Tiada waris / penjamin — pesakit hadir seorang diri (nama, IC & tandatangan waris tidak diperlukan).": "No guardian / surety — patient attends alone (guardian name, IC & signature not required).",
    "Tiada waris / penjamin — saya hadir seorang diri.": "No guardian / surety — I am attending alone.",
    "Anda tidak mempunyai kebenaran edit bayaran.": "You do not have permission to edit payments.",
    "Anda tidak mempunyai kebenaran batalkan bayaran.": "You do not have permission to cancel payments.",
    "Anda tidak mempunyai kebenaran untuk buang tandatangan.": "You do not have permission to remove the signature.",
    "Bayaran dikemaskini ✅": "Payment updated ✅",
    "Bayaran dibatalkan ✅": "Payment cancelled ✅",
    "Diskaun tidak sah": "Invalid discount",
    "Tiada baki untuk direkod.": "No balance to record.",
    "Sila upload bukti bayaran (wajib kecuali tunai)": "Please upload proof of payment (required unless cash)",
    "Jumlah yang sah diperlukan.": "A valid amount is required.",
    "Sebab edit wajib diisi.": "An edit reason is required.",
    "Sebab batal wajib diisi.": "A cancellation reason is required.",
    // — Auth: mobile intro —
    'Mari kita mula!': "Let's get started!",
    'Log masuk untuk kekal sihat & cergas.': 'Login to stay healthy and fit.',
    'PDPA compliant · Data dilindungi': 'PDPA compliant · Data protected',

    // — Auth: desktop hero / support bar —
    'Selamat Datang': 'Welcome',
    'Platform digital anda untuk perjalanan pemulihan yang lebih tersusun dan efektif.': 'Your digital platform for a more organised and effective recovery journey.',
    'Selamat & Terjamin': 'Safe & Secure',
    'Data anda dilindungi dengan keselamatan tahap tinggi.': 'Your data is protected with high-level security.',
    'Pemantauan Perkembangan': 'Progress Monitoring',
    'Pantau kemajuan rawatan anda dengan mudah.': 'Track your treatment progress with ease.',
    'Sokongan Berterusan': 'Continuous Support',
    'Kami bersama anda sepanjang perjalanan pemulihan.': 'We are with you throughout your recovery journey.',
    'Kesihatan adalah harta yang paling berharga.': 'Health is the most precious treasure.',
    'Jaga minda, pulihkan jiwa, capai kehidupan yang lebih baik.': 'Care for the mind, heal the soul, achieve a better life.',
    'Sila masukkan email dan kata laluan anda.': 'Please enter your email and password.',
    'Sila lengkapkan maklumat di bawah.': 'Please complete the details below.',
    'atau': 'or',
    'PDPA Compliant · Data dilindungi · Ibnu Sina Wellness': 'PDPA Compliant · Data protected · Ibnu Sina Wellness',
    'Perlukan bantuan?': 'Need help?',
    'Hubungi kami': 'Contact us',

    // — Auth: login —
    'Log Masuk': 'Login',
    'Log masuk': 'Login',
    'Kata Laluan': 'Password',
    'Masukkan kata laluan': 'Enter your password',
    'Lupa kata laluan?': 'Forgot password?',
    'Belum ada akaun?': "Don't have an account?",
    'Daftar di sini': 'Sign up here',
    'Sedang log masuk...': 'Signing in...',
    'Email atau kata laluan salah': 'Wrong email or password',
    'Email dan kata laluan wajib diisi': 'Email and password are required',
    'Profil tidak dijumpai. Sila hubungi admin atau daftar semula.': 'Profile not found. Please contact admin or sign up again.',

    // — Auth: forgot password —
    'Reset Kata Laluan': 'Reset Password',
    'Masukkan email anda. Link reset akan dihantar ke email tersebut.': 'Enter your email. A reset link will be sent to it.',
    'Hantar Link Reset': 'Send Reset Link',
    'Menghantar...': 'Sending...',
    'Kembali ke Log Masuk': 'Back to Login',
    'Sila masukkan email': 'Please enter your email',

    // — Auth: signup —
    'Daftar': 'Sign Up',
    'Daftar Akaun Baru': 'Create New Account',
    'Nama Penuh': 'Full Name',
    'Nama penuh anda': 'Your full name',
    'Minimum 6 aksara': 'Minimum 6 characters',
    'Saya bersetuju dengan': 'I agree to the',
    'Terma Perkhidmatan': 'Terms of Service',
    'dan': 'and',
    'Dasar Privasi': 'Privacy Policy',
    'Daftar Akaun': 'Create Account',
    'Mendaftar...': 'Creating account...',
    'Sudah ada akaun?': 'Already have an account?',
    'Semua ruangan wajib diisi': 'All fields are required',
    'Kata laluan mestilah sekurang-kurangnya 6 aksara': 'Password must be at least 6 characters',
    'Email ini sudah didaftarkan. Sila log masuk atau guna email lain.': 'This email is already registered. Please log in or use another email.',
    'Format email tidak sah': 'Invalid email format',

    // — Auth: success —
    'Pendaftaran Berjaya!': 'Registration Successful!',
    'Sila semak email untuk pengesahan akaun.': 'Please check your email to confirm your account.',
    'PDPA compliant · Data dilindungi · Ibnu Sina Wellness': 'PDPA compliant · Data protected · Ibnu Sina Wellness',

    // — Chrome: topbar / user menu —
    'Profil': 'Profile',
    'Log Keluar': 'Log Out',
    'Notifikasi': 'Notifications',
    'Baca semua': 'Read all',
    'Tiada notifikasi': 'No notifications',
    'Memuatkan...': 'Loading...',
    'Kembali': 'Back',
    'Kecilkan': 'Collapse',
    'Pesakit': 'Patient',

    // — Chrome: patient sidebar nav —
    'Papan Pemuka': 'Dashboard',
    'Pelan Rawatan Saya': 'My Treatment Plan',
    'Pustaka Bantuan Diri': 'Self-Help Library',
    'Pembayaran': 'Payment',
    'Pesanan & Penjejakan': 'Orders & Tracking',
    'Lapor Isu': 'Report Issue',
    'Borang Pendaftaran': 'Registration Form',
    'Jadual Harian': 'Daily Schedule',
    'Pakej Rawatan': 'Treatment Package',
    'Catatan Harian': 'Daily Log',
    'Bacaan Saya': 'My Readings',
    'Rekod Perubatan': 'Medical Records',
    'Pulangan Botol': 'Bottle Return',
    'Surat Rasmi': 'Official Letter',
    'Artikel': 'Article',
    'Pengumuman': 'Announcement',
    'Produk': 'Product',
    'Catatan': 'Log',

    // — Patient dashboard —
    'Semoga hari ini lebih baik dari semalam.': 'May today be better than yesterday.',
    '📢 Pengumuman & Makluman': '📢 Announcements & Info',
    'Tiada pengumuman buat masa ini': 'No announcements at the moment',
    'Penting': 'Important',
    'Komuniti': 'Community',
    'Pakej Rawatan Semasa': 'Current Treatment Package',
    'Kemajuan Rawatan': 'Treatment Progress',
    '📅 Jumlah Minggu': '📅 Total Weeks',
    '🗓️ Sesi Minggu Ini': '🗓️ Sessions This Week',
    '⏭️ Sesi Seterusnya': '⏭️ Next Session',
    'Lihat Pelan Rawatan': 'View Treatment Plan',
    'Catatan Harian Hari Ini': "Today's Daily Log",
    'Kemaskini setiap hari untuk pemantauan tepat.': 'Update daily for accurate monitoring.',
    'Perasaan Hari Ini': "Today's Mood",
    'Belum diisi': 'Not filled yet',
    'Belum diisi hari ini': 'Not filled in today',
    'Sudah diisi': 'Filled in',
    '✍️ Isi Sekarang': '✍️ Fill Now',
    'Checklist Hari Ini': "Today's Checklist",
    'tugasan selesai': 'tasks completed',
    '✏️ Kemas Kini': '✏️ Update',
    'Sesi Minggu': 'Week',
    'Anda': 'You',
    'belum isi': "haven't filled in",
    'Catatan Harian hari ini. Konsistensi setiap hari membantu pemulihan anda lebih cepat — jangan lepaskan hari ini ya!': "today's Daily Log. Consistency every day helps you recover faster — don't skip today!",
    'Hari ini': 'Today',
    'Tiada': 'None',
    'Tiada sesi akan datang': 'No upcoming sessions',
    '🔄 Tukar': '🔄 Reschedule',
    '🔄 Perlu tukar': '🔄 Needs reschedule',
    'Disahkan': 'Confirmed',
    '❤️ Kesihatan Terkini': '❤️ Latest Health',
    'Kadar Jantung & Oksigen': 'Heart Rate & Oxygen',
    'Paras Gula': 'Sugar Level',
    'Tekanan Darah': 'Blood Pressure',
    'Rendah': 'Low',
    'Kurang': 'Low',
    'Berlebihan': 'High',
    '❤️ Tek. Darah': '❤️ Blood Pressure',
    '⚖️ Berat': '⚖️ Weight',
    'Tinggi (cm)': 'Height (cm)',
    'BMI (auto)': 'BMI (auto)',
    'Untuk kiraan BMI automatik.': 'For automatic BMI calculation.',
    '📋 Peringatan Rawatan': '📋 Treatment Reminders',
    'A. Sebelum Rawatan': 'A. Before Treatment',
    'B. Reaksi & Pemulihan': 'B. Reaction & Recovery',
    'C. Penjagaan Harian': 'C. Daily Care',

    // — Patient plan-week: daily-plan section headers (unit "Hari") —
    '✅ Bimbingan & Bekalan Hari Ini': '✅ Guidance & Supplies Today',
    '🎯 Goals Hari Ini': '🎯 Goals Today',
    '📚 Homework Hari Ini': '📚 Homework Today',
    '📎 Dokumen Hari Ini': "📎 Today's Documents",
    '⭐ Feedback Hari Ini': "⭐ Today's Feedback",

    // — PWA install chip —
    'Pasang': 'Install'
  };

  // Merge the auto-generated full-site glossary. Curated seed above WINS,
  // so we only fill in keys the seed doesn't already define.
  if (window.ISW_I18N_EXTRA) { for (var k in window.ISW_I18N_EXTRA) if (!(k in EN)) EN[k] = window.ISW_I18N_EXTRA[k]; }
  window.ISW_I18N_EN = EN;

  // ── Reverse glossary: English (source) → Malay ──────────────
  // Some UI text was authored directly in English (not translated from a BM
  // source). This dict lets BM mode translate that text too, instead of just
  // leaving it in English. Populated entirely from shared/i18n-dict-ms.js.
  var MS = {};
  if (window.ISW_I18N_EXTRA_MS) { for (var k3 in window.ISW_I18N_EXTRA_MS) MS[k3] = window.ISW_I18N_EXTRA_MS[k3]; }
  window.ISW_I18N_MS = MS;

  var SKIP_TAGS = { SCRIPT: 1, STYLE: 1, NOSCRIPT: 1, TEXTAREA: 1, CODE: 1, PRE: 1, SVG: 1 };
  var ATTRS = ['placeholder', 'title', 'aria-label'];
  // Elements marked data-i18n-skip (or inside one) keep their as-authored text
  // in both languages — used for labels that must never switch (e.g. a nav
  // item deliberately fixed to "Dashboard" regardless of BM/EN).
  var SKIP_ATTR = 'data-i18n-skip';
  function isSkipped(el) { return !!(el && el.closest && el.closest('[' + SKIP_ATTR + ']')); }

  // Normalize internal whitespace runs (incl. newlines from wrapped HTML source)
  // to a single space, so dict keys don't need to replicate source indentation.
  function normKey(s) { return s.replace(/\s+/g, ' ').trim(); }

  function translate(s) {
    if (s == null) return null;
    var key = normKey(s);
    if (!key) return null;
    var t = EN[key];
    if (t == null) return null;
    var lead = s.match(/^\s*/)[0];
    var trail = s.match(/\s*$/)[0];
    return lead + t + trail;
  }

  function translateToMs(s) {
    if (s == null) return null;
    var key = normKey(s);
    if (!key) return null;
    var t = MS[key];
    if (t == null) return null;
    var lead = s.match(/^\s*/)[0];
    var trail = s.match(/\s*$/)[0];
    return lead + t + trail;
  }

  // Resolves the text to show for the given original (as-authored) string:
  // BM source → EN dict when lang is 'en'; English-authored source → MS dict
  // when lang is 'ms'. Falls back to the original when no entry matches.
  function resolve(orig, lang) {
    var t = lang === 'en' ? translate(orig) : translateToMs(orig);
    return t != null ? t : orig;
  }

  function handleTextNode(node, lang) {
    if (!node.nodeValue || !node.nodeValue.trim()) return;
    var p = node.parentNode;
    if (p && SKIP_TAGS[p.nodeName]) return;
    if (isSkipped(p)) return;
    if (node.__iswOrig == null) node.__iswOrig = node.nodeValue;
    var next = resolve(node.__iswOrig, lang);
    if (node.nodeValue !== next) node.nodeValue = next;
  }

  function handleAttrs(el, lang) {
    if (isSkipped(el)) return;
    for (var i = 0; i < ATTRS.length; i++) {
      var a = ATTRS[i];
      if (!el.hasAttribute || !el.hasAttribute(a)) continue;
      var ck = '__iswOrig_' + a;
      if (el[ck] == null) el[ck] = el.getAttribute(a);
      var next = resolve(el[ck], lang);
      if (el.getAttribute(a) !== next) el.setAttribute(a, next);
    }
  }

  function walk(root, lang) {
    if (!root) return;
    if (root.nodeType === 3) { handleTextNode(root, lang); return; }
    if (root.nodeType !== 1) return;
    if (SKIP_TAGS[root.nodeName]) return;

    var tw = document.createTreeWalker(root, NodeFilter.SHOW_TEXT, null);
    var n, batch = [];
    while ((n = tw.nextNode())) batch.push(n);
    for (var i = 0; i < batch.length; i++) handleTextNode(batch[i], lang);

    if (root.hasAttribute) handleAttrs(root, lang);
    var withAttr = root.querySelectorAll('[placeholder],[title],[aria-label]');
    for (var j = 0; j < withAttr.length; j++) handleAttrs(withAttr[j], lang);
  }

  function updateToggle() {
    var label = getLang() === 'en' ? 'EN' : 'BM';
    var btns = document.querySelectorAll('[data-isw-lang-btn]');
    // Guard: only write when changed. Unconditional textContent writes would
    // create childList mutations that re-trigger the observer -> infinite loop.
    for (var i = 0; i < btns.length; i++) {
      if (btns[i].textContent !== label) btns[i].textContent = label;
    }
  }

  function apply() {
    var lang = getLang();
    walk(document.body, lang);
    document.documentElement.lang = lang === 'en' ? 'en' : 'ms';
    updateToggle();
  }

  function setLang(l) {
    localStorage.setItem(STORE, l === 'en' ? 'en' : 'ms');
    apply();
    try { document.dispatchEvent(new CustomEvent('isw:langchange', { detail: { lang: getLang() } })); } catch (e) {}
  }

  window.iswGetLang = getLang;
  // Teks dinamik / prompt() / confirm() — enjin padanan-tepat tak boleh terjemah rentetan
  // berinterpolasi atau dialog asli. Guna iswL('Bahasa Melayu', 'English') dan bina KEDUA-DUA
  // versi di tapak panggilan (bahasa semasa dipilih pada masa panggilan).
  window.iswL = function (ms, en) { return getLang() === 'en' ? en : ms; };
  window.iswSetLang = setLang;
  window.iswApplyI18n = apply;
  window.iswToggleLang = function () { setLang(getLang() === 'en' ? 'ms' : 'en'); };

  // ── Observe dynamically-added content (navbar/topbar/lists) ──
  var mo = new MutationObserver(function (muts) {
    var lang = getLang();
    for (var i = 0; i < muts.length; i++) {
      var added = muts[i].addedNodes;
      for (var j = 0; j < added.length; j++) walk(added[j], lang);
    }
    updateToggle();
  });

  function init() {
    apply();
    if (document.body) mo.observe(document.body, { childList: true, subtree: true });
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
  else init();
})();
