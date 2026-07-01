# Panduan: Inventori & Kit Prosedur 🟢

[← Kembali ke indeks panduan](../README.md)

---

## 1. Tujuan
Urus semua bekalan fizikal yang sistem guna — tambah item inventori (madu, supplement, sarung tangan, DNA kit, dll.), laras stok bila terima/guna/buang, dan bina **Kit Prosedur** (himpunan beberapa item jadi satu set). Stok ini akan **auto-tolak** bila coach tanda sesi *Hadir* dan **auto-sync** dengan stok produk kedai (ikut nama yang sama).

## 2. Siapa boleh buat
Staf dengan kebenaran modul **`inventory`**:
- **Lihat** senarai & detail — semua staf yang ada akses modul (`view`).
- **Tambah / Edit / Laras stok** — perlu kebenaran `create` / `edit` (biasanya `admin`, `manager`).
- **Lulus / Tolak permohonan beli** — perlu kebenaran `approve` (manager).
- **Tandakan Dibeli** (terima stok PO) — `admin`.
- **Bina / Edit Kit Prosedur** — `admin` atau `manager`.

(Lihat [Peranan & Akses](../../sistem/05-peranan-akses.md).)

## 3. Lokasi
- **Senarai inventori:** Sidebar staf → **OPERASI → Inventori** (`roles/staff/inventory.html`)
  - 3 tab: **📦 Inventori** · **🧰 Kit Prosedur** · **📋 Permohonan**
- **Detail item:** klik mana-mana baris item → `roles/staff/inventory-detail.html?id=…`
- **Bina / edit kit:** tab **Kit Prosedur** → **+ Tambah Kit**, atau page khas Kit Prosedur (`roles/staff/kit-prosedur.html`) → borang `roles/staff/kit-edit.html`

---

## 4. Langkah ringkas

### A. Tambah item inventori
1. Buka **Inventori** → tab **📦 Inventori** → klik **+ Tambah Item**.
2. Isi **Nama Item** + pilih **Jenis Penggunaan** (Bekalan Coaching / Bekalan Perubatan).
3. Pilih **Kategori** + **Unit**, isi **Stok Semasa** + **Stok Minimum**.
4. (Pilihan) Set **Auto-PO** + toggle **Perlu Kelulusan Manager**.
5. Klik **💾 Simpan Item**.

### B. Laras stok
1. Buka **detail item** (klik baris) → **⚖️ Laras Stok**.
2. Pilih **Jenis Pergerakan**: `+ Masuk` (terima), `− Guna / Buang`, atau `= Set semula` (stock count).
3. Isi **Kuantiti** + (pilihan) **Nota** → **Simpan**.

> Modal ringkas di senarai (tab Inventori) hanya `Laras Stok = set stok baru`. Modal di **detail item** ada pilihan +/−/set yang lebih lengkap.

### C. Bina Kit Prosedur
1. Tab **🧰 Kit Prosedur** → **+ Tambah Kit**.
2. Isi **Nama Kit** (+ Kategori, Deskripsi pilihan).
3. Klik **+ Tambah Item** → taip **nama item** + **Qty** + **Unit** untuk setiap baris.
4. Klik **Simpan Kit**.

> Kit ialah cara pintas untuk masukkan satu set bekalan ke dalam minggu pakej sekali gus — bukannya pilih item satu-satu.

---

## 5. Field — wajib vs pilihan

### A. Modal Tambah/Edit Item (`inventory.html`)
| Field | Wajib? | Nota |
|-------|--------|------|
| **Nama Item** `*` | ✅ **WAJIB** | Sistem block kalau kosong. Nama ini juga kunci **auto-sync** dengan produk (mesti sama betul-betul). Cth: `Madu Tualang`, `DNA Test Kit`. |
| **Jenis Penggunaan** `*` | ✅ **WAJIB** | `Bekalan Coaching` (umum/`general`) atau `Bekalan Perubatan` (pakej). Tentukan cara kira keperluan stok — lihat nota di bawah jadual. |
| **Kategori** `*` | Disyorkan | Senarai tetap: Bekalan Coaching · Bekalan Rawatan · Madu & Produk · Starter Kit · Suplemen & Resepi · Buku & Bahan Cetak · Brosur & Marketing · Peralatan Konsultasi. |
| **Unit** `*` | Disyorkan | Unit · Botol · Kotak · Paket · Liter · Gram · Kilogram. |
| **Stok Semasa** `*` | Disyorkan | Jumlah stok ada sekarang. Default `0`. |
| **Stok Minimum (Reorder)** `*` | Disyorkan | Tahap reorder. Untuk jenis *Pakej* ia hanya **fallback** bila tiada patient aktif; untuk *Umum* ia angka trigger Auto-PO sebenar. |
| Kuantiti Auto-PO | Pilihan | Kuantiti tetap untuk top-up. Kosong = sistem auto-kira (pulih ke keperluan penuh, atau min × 3). |
| Auto-Trigger Purchase Invoice | Default OFF | Toggle. ON = sistem jana PI/permohonan beli automatik bila stok rendah. |
| Perlu Kelulusan Manager | Default OFF | ON = permohonan beli item ini perlu lulus manager dulu sebelum dibeli. |

> **Jenis Penggunaan menentukan logik stok:**
> - **Bekalan Perubatan / Pakej (`package`)** — sistem **auto-kira keperluan** = (patient aktif × qty/patient ikut jadual pakej). Auto-PO trigger bila stok **≤ 30%** keperluan. "Stok Minimum" jadi fallback sahaja.
> - **Bekalan Coaching / Umum (`general`)** — barang guna merentas semua aktiviti (sarung tangan, swab, tissue). Tiada auto-kira; Auto-PO trigger bila stok **≤ Stok Minimum**.

### B. Modal Edit Item (di `inventory-detail.html`)
Edit lanjut + maklumat supplier. Hanya **Nama** wajib. Field tambahan: Penerangan Produk, **Nama Supplier**, **Kos seunit (RM)**, **Lead time (hari)**, **Cadangan PO Min/Max**, checkbox **Perlu kelulusan**. (Disimpan dalam `supplier_info` JSON.)

### C. Modal Laras Stok
| Field | Wajib? | Nota |
|-------|--------|------|
| **Jenis Pergerakan** | (di detail) | `+ Masuk` · `− Guna / Buang` · `= Set semula`. |
| **Kuantiti / Stok Baru** `*` | ✅ **WAJIB** | Mesti > 0. |
| Catatan / Nota | Pilihan | Sebab pelarasan (cth: "Pembelian bulanan", "stok rosak"). |

### D. Borang Kit Prosedur (`kit-edit.html`)
| Field | Wajib? | Nota |
|-------|--------|------|
| **Nama Kit** `*` | ✅ **WAJIB** | Cth: `IV Drip Setup`. |
| Kategori | Pilihan | Default `Umum`. Cth: `IV Therapy`. |
| Deskripsi | Pilihan | Huraian ringkas bila kit ini digunakan. |
| **Senarai Item** `*` | ✅ **WAJIB** | Mesti ada **sekurang-kurangnya 1 item**. Setiap baris: **Nama Item** + **Qty** (>0) + **Unit**. |

> Item kit dipadan ke inventori **ikut nama** (taip nama sama macam item inventori) supaya auto-deduct berfungsi bila kit digunakan dalam pakej.

---

## 6. Apa jadi lepas Simpan

### Tambah/Edit item
1. Rekod ditulis ke **`psy_inventory_items`** (insert kalau baru, update kalau edit).
2. Item muncul dalam senarai, kira-kira keperluan (`dynamic_monthly`) dikira semula ikut patient aktif × supplies pakej.
3. Kalau stok di bawah threshold, **Auto-PO** boleh jana permohonan ke `psy_inventory_requests` (notifikasi ke admin/manager).

### Laras stok
1. `qty_in_stock` dikemaskini.
2. **Auto-sync ke produk:** sistem cari produk di `psy_products` dengan **nama sama** (case-insensitive) dan set stoknya sama → banner papar "Produk juga di-sync". (Lihat [`shared/stockSync.js`](../../../shared/stockSync.js).)

### Bina/edit kit
1. Rekod ditulis ke **`psy_procedure_kits`** (field `items` = JSON array `{item_name, qty, unit}`).
2. Kit boleh dipilih sebagai bekalan minggu dalam [borang pakej](tambah-pakej.md) (rujukan `{kit_id, qty}` — sistem kembang jadi sub-item).

### Auto-tolak stok (bila coach tanda *Hadir*)
1. Di `plan-week.html`, bila coach tanda sesi **✅ Hadir**, sistem panggil `deductSessionSupplies()`.
2. Sistem baca `coaching_schedule[minggu].supplies` dari pelan rawatan pesakit.
3. **Skip** kalau: sesi `is_extension`, mode `online`, item tiada `item_id`, qty 0, atau `auto_stock = false`.
4. Untuk setiap bekalan sah → `qty_in_stock` ditolak (tak boleh bawah 0).
5. Dicatat ke **`psy_audit_log`** (`action: inventory.auto_deducted`) + banner ringkasan; amaran kalau ada item jadi stok rendah.

(Lihat [`shared/inventoryDeduct.js`](../../../shared/inventoryDeduct.js).)

---

## 7. Masalah biasa
| Mesej / gejala | Sebab & penyelesaian |
|----------------|----------------------|
| "Nama wajib diisi" | Isi **Nama Item** / **Nama Kit** dulu. |
| "Kit mesti ada sekurang-kurangnya 1 item" | Tambah minimum 1 baris item dengan nama + qty. |
| "Masukkan kuantiti yang sah" | Kuantiti laras stok mesti > 0. |
| Stok tak auto-tolak bila tanda Hadir | Bekalan minggu mesti dipilih dari **picker Inventory** (ada `item_id`), bukan teks bebas. Sesi **online** & **extension** memang tak tolak stok. Pastikan `auto_stock` tak dimatikan. |
| Banner "Produk juga di-sync" tak muncul | Tiada produk dengan nama **sama betul-betul** di `psy_products`. Sync padan ikut nama — eja mesti sama (tak kira besar/kecil huruf). |
| Item "Pakej" tunjuk keperluan `0` / `—` | Tiada patient aktif pada pakej yang guna item ini, **atau** nama item tak padan dengan entri supplies pakej. Semak jadual pakej. |
| Auto-PO tak jana walaupun stok rendah | Threshold = 0 (item pakej tiada patient + min_qty 0), atau dah ada permohonan `pending/approved`, atau dalam cooldown 24 jam (`last_auto_po_at`). |
| Item dalam kit tak tolak stok | Nama item dalam kit mesti padan nama di Inventori. Item kit disimpan sebagai nama (`item_id: null`) — padanan ikut nama. |

---

## 8. Rujukan teknikal
- Pages:
  - [`roles/staff/inventory.html`](../../../roles/staff/inventory.html) — senarai, stat, Auto-PO (`checkAutoPO()`), kira keperluan (`computeDynamicDemand()`)
  - [`roles/staff/inventory-detail.html`](../../../roles/staff/inventory-detail.html) — detail, edit+supplier, laras stok (`saveAdjust()`), pergerakan
  - [`roles/staff/kit-edit.html`](../../../roles/staff/kit-edit.html) · [`roles/staff/kit-prosedur.html`](../../../roles/staff/kit-prosedur.html) — bina/senarai kit
- Auto-sync inventori ↔ produk (ikut nama): [`shared/stockSync.js`](../../../shared/stockSync.js) — `syncStockToProducts()`, `syncStockToInventory()`, `ensureInventoryCounterpart()`
- Auto-tolak stok bila tanda Hadir: [`shared/inventoryDeduct.js`](../../../shared/inventoryDeduct.js) — `deductSessionSupplies()`; dipanggil dari `plan-week.html` (`markStatus('hadir')` / `upsertProgress`)
- Jadual: `psy_inventory_items`, `psy_inventory_requests`, `psy_procedure_kits`, `psy_products` (lihat [02-pangkalan-data.md](../../sistem/02-pangkalan-data.md))
- Berkaitan: [Tambah / Edit Pakej](tambah-pakej.md) (di mana bekalan & kit dipilih per minggu)
