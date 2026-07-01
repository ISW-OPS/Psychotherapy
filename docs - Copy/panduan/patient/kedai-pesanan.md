# Panduan: Beli Produk, Jejak Pesanan & Pulangan Botol 🔵

[← Kembali ke indeks panduan](../README.md)

---

## 1. Tujuan
Panduan untuk **pesakit** ISW membeli produk individu (top-up) di Kedai, menjejak status pesanan dari bayaran sampai diterima (termasuk tracking courier), dan memohon **pulangan botol madu kosong** untuk diverify staff. Tiga aliran ini digabung kerana saling berkait: Kedai → Pesanan → (kemudian) Pulangan.

> Untuk **pakej rawatan utama** (langganan), bukan di sini — sila ke [Pakej Rawatan](../../../roles/patient/pakej.html). Kedai hanya untuk beli produk individu (à la carte) tanpa pakej.

## 2. Siapa boleh buat
Mana-mana **pesakit** yang sudah log masuk ke akaun ISW. Tiada kebenaran khas — setiap pesakit nampak Kedai, Pesanan, dan Pulangan sendiri sahaja (data dikunci ikut akaun melalui Row Level Security). (Lihat [Peranan & Akses](../../sistem/05-peranan-akses.md).)

## 3. Lokasi
- **Kedai (beli produk):** Navigasi pesakit → **🛒 Shop** (`roles/patient/shop.html`)
- **Pesanan & Tracking:** dari Shop → pautan **"📦 Lihat Orders & Tracking →"**, atau terus (`roles/patient/orders.html`)
- **Pulangan Botol:** menu pesakit → **Pulangan Botol** (`roles/patient/pulangan.html`)
- **Pembayaran:** selepas checkout, sistem bawa ke `roles/patient/payment.html`

---

## 4. Langkah ringkas

### A — Beli Produk (Kedai)
1. Buka **🛒 Shop**.
2. (Pilihan) Tapis ikut **kategori** di bar atas (cth: `Madu`, atau `All`).
3. Klik **+ Add** pada produk yang dimahukan.
4. Klik butang troli terapung **🛒 (bilangan · jumlah)** di bawah-kanan.
5. Laras kuantiti dengan **−** / **+** dalam troli.
6. Pilih **Kaedah Penghantaran**: 🏥 **Pickup Konsultasi** (percuma) atau 🚚 **Pos / Courier** (+RM 8.00).
7. Kalau Pos: isi **Alamat Penghantaran**.
8. Klik **Teruskan ke Bayaran →** → buat bayaran di halaman Payment.

### B — Jejak Pesanan
1. Buka **📦 Orders & Tracking**.
2. Pilih tab: **Aktif · Semua · Selesai · Batal**.
3. Klik mana-mana pesanan untuk buka **timeline status**.
4. Untuk Pos: klik **Track →** guna nombor tracking courier.
5. Bila parsel sampai, klik **✅ Saya Dah Terima Parsel**.

### C — Pulangan Botol
1. Buka **Pulangan Botol** → tab **🍯 Hantar Pulangan Baru**.
2. Tick **semua 4 syarat** botol.
3. Isi **kuantiti botol**.
4. Upload **foto bukti** (wajib, boleh banyak).
5. (Pilihan) tulis **nota**.
6. Klik **Hantar Permohonan**.
7. Pantau di tab **📋 Pulangan Saya** + sembang dengan staff.

> Troli disimpan dalam browser sahaja sehingga checkout — ia belum jadi pesanan sebenar dalam database sampai bayaran dibuat.

---

## 5. Field — wajib vs pilihan

### A — Kedai / Troli (`shop.html`)
| Field / Pilihan | Wajib? | Nota |
|-----------------|--------|------|
| Produk (+ Add) | ✅ Sekurangnya 1 | Troli kosong = sistem block checkout ("Cart kosong"). Produk **Habis Stok** tak boleh tambah (butang "Habis"). |
| Kuantiti (− / +) | Default `1` | Laras dalam troli. Tolak sampai 0 = item keluar troli. |
| **Kaedah Penghantaran** | ✅ | 🏥 **Pickup Konsultasi** = percuma · 🚚 **Pos / Courier** = +RM 8.00. Default Pickup. |
| **Alamat Penghantaran** | ✅ kalau **Pos** | Block kalau Pos tapi alamat kosong ("Sila masukkan alamat penghantaran"). Pickup tak perlu alamat. |

> Harga **PROMO** (kalau ada) dipakai automatik dalam troli — harga asal dipalang, harga promo merah jadi harga sebenar. Badge **Tinggal N** muncul bila stok ≤ 5.

### B — Pulangan Botol (`pulangan.html`)
| Field | Wajib? | Nota |
|-------|--------|------|
| **4 Syarat (checkbox)** `*` | ✅ **SEMUA** | (1) Tidak berkarat · (2) Bersihkan dulu · (3) Getah masih ada · (4) Besi penutup tak longgar. Butang Hantar kekal mati sehingga semua 4 ditick. |
| **Kuantiti Botol** `*` | ✅ | Mesti ≥ 1 (max 100). |
| **Foto Bukti** `*` | ✅ | Sekurangnya 1 foto. JPG/PNG, **maks 5MB setiap satu**, boleh upload banyak. |
| Nota | Pilihan | Cth: bila boleh hantar, kekurangan, dll. |

> Butang **Hantar Permohonan** hanya aktif bila **3 syarat dipenuhi serentak**: semua 4 checkbox ditick, sekurangnya 1 foto, dan kuantiti > 0.

### Status pesanan (timeline) — apa maksudnya
| Status | Papar pesakit | Maksud |
|--------|---------------|--------|
| `pending` | ⏳ Menunggu Pembayaran | Order dibuat, belum dibayar. |
| `paid` | Dibayar | Bayaran diterima. |
| `packed` | Sedang Disediakan | Staf sedang bungkus. Untuk Pickup: **📍 Sedia untuk Diambil**. |
| `shipped` | Dalam Penghantaran | Dah dihantar (ada tracking number) — butang **✅ Saya Dah Terima Parsel** muncul. |
| `delivered` | Selesai | Parsel diterima / diambil. |
| `cancelled` | Dibatalkan | Order dibatalkan. |

> Timeline **berbeza** ikut kaedah: Pos = 🛒 → 💳 → 📦 Dibungkus → 🚚 Dihantar → ✅ Diterima. Pickup = 🛒 → 💳 → 📍 Sedia Pickup → ✅ Diambil.

---

## 6. Apa jadi lepas hantar

### Beli Produk
1. Klik **Teruskan ke Bayaran** simpan butiran order (item, subtotal, fi penghantaran RM 8, alamat) ke browser (`isw_pending_payment`) dan jana **Order Ref** (cth `ORD-XXXX-XXXX`).
2. Diarah ke **`payment.html`** — pesanan **belum** wujud dalam database sampai bayaran selesai.
3. Selepas bayar, rekod ditulis ke jadual **`psy_orders`** dengan status bermula `pending`/`paid`.
4. Order muncul di **Orders & Tracking** (tab Aktif).

### Jejak Pesanan
1. Klik **✅ Saya Dah Terima Parsel** mengemaskini `psy_orders` → `status = delivered` + cap masa `delivered_at`.
2. Order berpindah ke tab **Selesai**. Banner "Terima kasih! Status order dikemaskini." muncul.
3. Status lain (`packed`, `shipped`, nombor tracking) di-set oleh **staf**, bukan pesakit.

### Pulangan Botol
1. Foto di-upload ke storan (`issue-photos`), rekod ditulis ke jadual **`psy_bottle_returns`** dengan `status = pending`.
2. Permohonan muncul di tab **📋 Pulangan Saya** dengan chip **⏳ Menunggu Verify**.
3. Boleh **sembang dengan staf** terus dari kad pulangan (mesej disimpan ke `psy_audit_log`, tag `bottle_return.message`).
4. Staf verify bila botol sampai konsultasi → status jadi **✅ Diterima** (`received`) atau **❌ Ditolak** (`rejected`, dengan alasan tolak).

---

## 7. Masalah biasa
| Mesej / gejala | Sebab & penyelesaian |
|----------------|----------------------|
| "Cart kosong" masa checkout | Tiada item dalam troli. Tambah produk dulu (+ Add). |
| "Sila masukkan alamat penghantaran" | Pilih Pos tapi alamat kosong. Isi alamat, atau tukar ke Pickup. |
| Butang produk tertulis "Habis" | Produk Habis Stok — tak boleh beli sehingga staf restock. |
| Butang **Hantar Permohonan** (pulangan) kekal mati | Belum tick **semua 4 syarat**, atau belum upload foto, atau kuantiti 0. Lengkapkan ketiga-tiga. |
| "Beberapa foto > 5MB — sila pilih semula" | Ada foto melebihi 5MB. Kecilkan foto sebelum upload. |
| "Rekod pesakit tidak ditemui" (pulangan) | Sesi/akaun tak link betul. Muat semula halaman; kalau masih, log keluar & masuk semula. |
| Butang **Track →** tak muncul | Order belum status `shipped` atau staf belum isi nombor tracking. Tunggu kemaskini staf. |
| Order tak nampak selepas bayar | Pastikan bayaran benar-benar selesai di `payment.html`. Order hanya wujud selepas pembayaran direkod. |

---

## 8. Rujukan teknikal
- Kedai: [`roles/patient/shop.html`](../../../roles/patient/shop.html) · `checkout()` ~ baris 271
- Pesanan: [`roles/patient/orders.html`](../../../roles/patient/orders.html) · `confirmDelivered()` ~ baris 295
- Pulangan: [`roles/patient/pulangan.html`](../../../roles/patient/pulangan.html) · `submitReturn()` ~ baris 225
- Bayaran: [`roles/patient/payment.html`](../../../roles/patient/payment.html)
- Jadual: `psy_products`, `psy_orders`, `psy_bottle_returns` (lihat [02-pangkalan-data.md](../../sistem/02-pangkalan-data.md))
- Chat pulangan disimpan dalam `psy_audit_log` (action `bottle_return.message`, `meta.return_id`)
