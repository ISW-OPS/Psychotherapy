# Panduan: Produk & Kedai (E-Dagang) 🟢

[← Kembali ke indeks panduan](../README.md)

---

## 1. Tujuan
Tambah (atau kemaskini) produk untuk **Kedai pesakit** (shop à la carte) — termasuk nama, harga, gambar, stok, kategori dan tetapan paparan. Produk yang **Aktif** akan muncul untuk pesakit beli secara individu tanpa pakej.

> **Penting:** Setiap produk WAJIB datang dari **Inventori** sebagai *source of truth*. Stok produk auto-sync dengan item inventori dengan **nama yang sama**. Sebab itu, untuk produk baru anda **mesti pilih item dari Inventori dulu** — bukan taip nama bebas.

## 2. Siapa boleh buat
Staf dengan kebenaran modul **`products`** — biasanya `super_admin`, `admin`, `manager`. (Lihat [Peranan & Akses](../../sistem/05-peranan-akses.md).)
- Butang **+ Tambah Produk** hanya muncul kalau ada kebenaran `products.create`.
- Butang **🗑️ Padam** hanya muncul kalau ada kebenaran `products.delete`.

## 3. Lokasi
- **Senarai produk:** Sidebar staf → **OPERASI → Produk** (`roles/staff/products.html`)
- **Borang tambah/edit:** `roles/staff/product-edit.html`
  - Tambah baru: butang **"+ Tambah Produk"** di `products.html`
  - Edit: klik ikon **✏️** pada baris produk, atau buka detail → **✏️ Edit Produk**
- **Detail produk:** `roles/staff/product-detail.html` (lihat ringkasan, log aktiviti)
- **Pesakit nampak di:** `roles/patient/shop.html` (Kedai)

---

## 4. Langkah ringkas

1. Buka **Produk** → klik **+ Tambah Produk**.
2. Skrin paparkan banner **"Pilih item dari Inventori dulu"** → klik **📦 Pilih dari Inventori**.
3. Dalam modal picker, cari & pilih item → **✓ Pilih Item**.
   - Nama, SKU, unit, stok & min-stok auto-isi dari item inventori dan **dikunci** (read-only) supaya nama kekal padan.
4. Lengkapkan **Maklumat Asas** (kategori, status, penerangan).
5. Isi **Harga & Jualan** (harga jualan wajib; harga promosi pilihan).
6. (Pilihan) Semak **Stok & Inventori**, tetapan jejak inventori & amaran stok rendah.
7. (Pilihan) **Muat naik imej** produk, isi **Butiran Tambahan** (berat, supplier, tag, notes).
8. Semak **Visibility / Publication** (tunjuk di shop, featured, benarkan beli online).
9. Klik **💾 Simpan Produk**.

> **Edit produk sedia ada** tidak melalui picker — semua field boleh diubah terus.
> Boleh klik **💾 Simpan Draft** — ia set status ke `Draft` dan simpan (produk tak muncul di shop sampai diaktifkan).

---

## 5. Field — wajib vs pilihan

### Seksyen 1 — Maklumat Asas
| Field | Wajib? | Nota |
|-------|--------|------|
| **Nama Produk** `*` | ✅ **WAJIB** | Sistem block kalau kosong. Untuk produk baru, auto-isi dari Inventori & **dikunci**. Cth: `Young & Healthy Honey 500g` |
| **SKU / Product ID** `*` | ✅ **WAJIB** | Sistem block kalau kosong. Untuk produk baru, auto-jana dari nama (slug) & dikunci. Cth: `madu-yhh-500` |
| **Kategori** `*` | ✅ **WAJIB** | Sistem block kalau kosong. `Madu` · `Herba` · `Air Terapi` · `Supplements` · `Lain-lain` |
| Jenama | Pilihan | Cth: `Ibnu Sina Wellness` |
| **Status** `*` | Default `Aktif` | `Aktif` (muncul di shop) · `Draft` · `Tidak Aktif` |
| Penerangan ringkas | Pilihan | Maks 200 aksara. Dipapar di kad shop pesakit. |

### Seksyen 2 — Harga & Jualan
| Field | Wajib? | Nota |
|-------|--------|------|
| **Harga jualan (RM)** `*` | ✅ **WAJIB** | Sistem block kalau kosong / negatif. `0` = dipapar **"Percuma"**. |
| Harga promosi (RM) | Pilihan | Kosongkan jika tiada promo. Promo aktif bila harga promo `> 0` dan `< harga jualan`. |
| Tarikh tamat promosi | Pilihan | Selepas tarikh ini, harga jualan asal digunakan semula. Kosong = promo tiada had tamat. |

### Seksyen 3 — Stok & Inventori
| Field | Wajib? | Nota |
|-------|--------|------|
| **Stok semasa** `*` | Disyorkan | Jumlah unit. Untuk produk baru, auto-isi dari Inventori & dikunci. Kosong = `0`. |
| **Minimum stok** `*` | Default `5` | Ambang amaran "stok rendah". |
| **Unit** `*` | Default `unit` | `unit` · `botol` · `kg` · `gram` · `sachet` · `pak` · `set` · `kotak`. Auto dari Inventori & dikunci untuk produk baru. |
| Jejak inventori (toggle) | Default **ON** | Kemas kini stok automatik bila jualan berlaku. |
| Amaran stok rendah (toggle) | Default **ON** | Notifikasi bila stok ≤ minimum. |

### Seksyen 4 — Media Produk
| Field | Wajib? | Nota |
|-------|--------|------|
| Imej produk | Pilihan | PNG / JPG, **maks 2MB**. Imej utama dipapar di shop & senarai produk. Tiada imej = ikon default (📦). |

### Seksyen 5 — Butiran Tambahan
| Field | Wajib? | Nota |
|-------|--------|------|
| Berat / Saiz | Pilihan | Cth: `500g` / `1kg` / `30ml` |
| Supplier | Pilihan | Cth: `Ibnu Sina Supplier` |
| Tag / Label | Pilihan | Tekan **Enter** untuk tambah satu-satu. |
| Notes | Pilihan | Catatan dalaman. Maks 500 aksara. |

### Seksyen 6 — Visibility / Publication
| Field | Wajib? | Nota |
|-------|--------|------|
| Produk kelihatan di shop (toggle) | Default **ON** | Papar di senarai shop pesakit. |
| Produk pilihan / featured (toggle) | Default **OFF** | Tanda sebagai produk pilihan. |
| Benarkan pembelian online (toggle) | Default **ON** | Pelanggan boleh beli produk ini secara online. |

---

## 6. Apa jadi lepas Simpan
1. Rekod ditulis ke jadual **`psy_products`** (insert kalau baru, update kalau edit).
2. `is_active` diset ikut status (`active` = `true`).
3. **Stok auto-sync ke Inventori** — `syncStockToInventory(nama, stok)` cari item `psy_inventory_items` dengan **nama sama** (case-insensitive) dan kemas kini `qty_in_stock`. (Lihat [`shared/stockSync.js`](../../../shared/stockSync.js).)
4. Tindakan dicatat ke audit log: `product.created` / `product.updated` (`psy_audit_log`) — muncul di **Log Aktiviti** pada detail produk.
5. Diarah ke **`product-detail.html`** untuk produk tersebut.
6. Produk kini muncul untuk pesakit di `roles/patient/shop.html` (kalau status **Aktif** + **kelihatan di shop**).

> **Arah sync 2-hala:** kalau stok diubah di **Inventori**, `syncStockToProducts()` akan kemas kini balik produk dengan nama sama. Di shop pesakit, stok dipapar ikut keutamaan: (1) FK `inventory_item_id`, (2) padanan nama Inventori, (3) lajur `stock` produk.

---

## 7. Masalah biasa
| Mesej / gejala | Sebab & penyelesaian |
|----------------|----------------------|
| "Nama produk diperlukan" | Pilih item dari Inventori dulu (produk baru) atau isi nama. |
| "SKU diperlukan" | SKU kosong — auto-jana dari nama, atau isi manual (edit). |
| "Sila pilih kategori" | Pilih satu kategori dalam dropdown. |
| "Harga tidak sah" | Harga kosong / negatif. Isi nombor ≥ 0. |
| "Imej terlalu besar (max 2MB)" | Kecilkan imej sebelum muat naik. |
| Picker Inventori kosong / item tak boleh dipilih | Item bertanda **✓ Dah jadi produk** (sudah ada produk nama sama) atau **⛔ Stok kosong** tidak boleh dipilih. Tiada item sesuai? **Tambah di Inventori dulu** (`inventory.html`). |
| Nama / SKU / stok tak boleh diubah | Normal untuk produk baru — field dikunci supaya nama padan dengan Inventori. Untuk ubah stok, kemas kini di **Inventori** (auto-sync). |
| Produk tak muncul di shop pesakit | Pastikan status **Aktif** (`is_active`) DAN toggle **kelihatan di shop** ON. |
| Stok di shop tunjuk 0 walau ada stok | Nama produk tak padan mana-mana item Inventori. Samakan nama, atau pastikan ada `inventory_item_id`. |

---

## 8. Rujukan teknikal
- Senarai: [`roles/staff/products.html`](../../../roles/staff/products.html)
- Borang: [`roles/staff/product-edit.html`](../../../roles/staff/product-edit.html) · `saveProduct()` ~ baris 420
- Detail: [`roles/staff/product-detail.html`](../../../roles/staff/product-detail.html)
- Auto-sync stok ⇄ Inventori: [`shared/stockSync.js`](../../../shared/stockSync.js) (`syncStockToInventory`, `syncStockToProducts`, `ensureInventoryCounterpart`)
- Paparan pesakit: [`roles/patient/shop.html`](../../../roles/patient/shop.html) · `loadProductsFromDB()`
- Jadual: `psy_products`, `psy_inventory_items` (lihat [02-pangkalan-data.md](../../sistem/02-pangkalan-data.md))
