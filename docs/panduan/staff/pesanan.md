# Panduan: Pesanan & Tracking (Orders) 🟢

[← Kembali ke indeks panduan](../README.md)

---

## 1. Tujuan
Urus pesanan kedai yang masuk dari pesakit — sahkan bayaran, bungkus, hantar parsel + isi nombor tracking, dan tandakan selesai. Setiap perubahan status menghantar notifikasi automatik ke pesakit, mengemaskini timeline pesakit, dan dicatat dalam audit log.

## 2. Siapa boleh buat
Staf dengan kebenaran modul **`orders`**. (Lihat [Peranan & Akses](../../sistem/05-peranan-akses.md).)
- **`orders` edit** — boleh tukar status, hantar parsel + isi tracking (butang "Hantar + Tracking" hanya muncul kalau ada kebenaran ini).
- **`orders` export** — boleh nampak baris statistik (Stat Cards) di atas.

## 3. Lokasi
- **Senarai pesanan (staf):** Sidebar staf → **OPERASI → Orders & Tracking** (`roles/staff/orders.html`)
- **Paparan pesakit:** `roles/patient/orders.html` (pesakit nampak status + timeline + tracking sendiri sahaja)

---

## 4. Langkah ringkas

Setiap pesanan bergerak ikut aliran status: **Pending → Dibayar (paid) → Dibungkus (packed) → Dihantar (shipped) → Diterima (delivered)**.

1. Buka **Orders & Tracking**. Pesanan baru default ditapis ke chip **"Perlu Dihantar"** (paid + packed).
2. Cari pesanan guna kotak carian (nama pesakit atau no. order) atau klik chip status.
3. **Pending** → klik **✓ Sahkan Bayaran** (jadi `paid`). Atau **Batalkan** kalau perlu.
4. **Dibayar (paid)** → klik **📦 Tandakan Dibungkus** (pos) / **✅ Tandakan Sedia Pickup** (pickup). Stok ditolak di sini.
5. **Dibungkus (packed), pos** → klik **🚚 Hantar + Tracking** → modal terbuka:
   - Pilih **Kurier**, isi **Tracking Number** (wajib), (pilihan) upload gambar parsel/resit.
   - Klik **Tandakan Dihantar** (jadi `shipped`).
6. **Dibungkus (packed), pickup** → klik **✅ Sedia Pickup** (terus jadi `delivered`).
7. **Dihantar (shipped)** → tunggu pesakit klik "Saya Dah Terima Parsel". Boleh **Force Diterima** kalau perlu tandakan manual.

> Klik **Detail** pada mana-mana pesanan untuk lihat penuh: item, alamat, cap masa setiap status, dan maklumat tracking.

---

## 5. Field — wajib vs pilihan

### Carian & penapis (atas senarai)
| Kawalan | Nota |
|---------|------|
| Kotak carian | Cari ikut **nama pesakit** atau **no. order** (`order_ref`). |
| Susun | `Terbaru dulu` (default) · `Terlama dulu` · `Jumlah ↓` |
| Kad / Jadual | Tukar paparan senarai (kad atau jadual). |
| Chip status | `Perlu Dihantar` (default) · Semua · Pending · Dibayar · Dibungkus · Dihantar · Diterima · Batal. Setiap chip ada kiraan. |

### Modal "🚚 Hantar Parsel"
| Field | Wajib? | Nota |
|-------|--------|------|
| **Tracking Number** `*` | ✅ **WAJIB** | Satu-satunya field yang sistem block kalau kosong ("Masukkan tracking number dahulu"). Cth: `JT1234567890` |
| Kurier | Default `J&T Express` | Pilihan: J&T Express · Pos Laju · DHL · Ninja Van · Grab Express · Lain-lain |
| Gambar Parsel / Resit | Pilihan | JPG/PNG. Disimpan ke storage `order-photos`; pesakit nampak dalam tracking mereka. Kalau upload gagal, status tetap dikemaskini (gambar di-skip). |

> **Pickup vs Pos** ditetapkan masa pesakit buat order (`delivery_method`), bukan di sini. Order pickup **tidak** ada modal tracking — terus dari packed ke diterima.

---

## 6. Apa jadi lepas tukar status
Setiap kali status ditukar (fungsi `markStatus`):
1. Rekod dikemaskini di jadual **`psy_orders`** — `status`, `updated_at`, dan cap masa berkaitan (`paid_at` / `packed_at` / `shipped_at` / `delivered_at`).
2. **Stok ditolak** kali pertama masuk `packed` — `psy_products` dikurangkan ikut item, dan disync ke Inventori ikut nama (`shared/stockSync.js`).
3. **Stok dipulangkan** kalau order dibatalkan selepas `packed`/`shipped`.
4. Tindakan dicatat ke audit log: `order.paid` / `order.packed` / `order.shipped` / `order.delivered` / `order.cancelled` (`psy_audit_log`), termasuk `order_ref` dan status sebelum.
5. **Notifikasi** dihantar ke pesakit (`psy_notifications`) dengan mesej ikut status (cth dihantar: sertakan no. tracking). Pesakit nampak di `roles/patient/orders.html`.
6. Pada `shipped`: `tracking_number`, `courier`, dan `tracking_photo_url` (jika ada) disimpan ke pesanan.
7. Timeline pesakit bergerak ke step seterusnya. Untuk pos: Order Dibuat → Bayaran → Dibungkus → Dihantar → Diterima. Untuk pickup: Order Dibuat → Bayaran → Sedia Pickup → Diambil. Order pos yang `shipped` ada butang **Track →** (link semakan J&T) di pihak pesakit.

---

## 7. Masalah biasa
| Mesej / gejala | Sebab & penyelesaian |
|----------------|----------------------|
| "Masukkan tracking number dahulu" | Field **Tracking Number** dalam modal hantar kosong. Isi dahulu. |
| Butang "Hantar + Tracking" tak muncul | Tiada kebenaran **`orders` edit**. Minta admin tambah peranan. |
| Stat Cards tak nampak | Tiada kebenaran **`orders` export** — normal untuk sesetengah peranan. |
| Stok tak berkurang | Stok hanya ditolak masa **kali pertama** masuk `packed`. Item perlu ada `id` + `qty` dan wujud di `psy_products`. |
| Gambar parsel tak naik | Upload gagal (di-skip secara senyap) — status tetap jadi `shipped`. Cuba upload semula dari Detail, atau abaikan (pilihan sahaja). |
| Order pickup tiada butang tracking | Memang betul — order pickup terus dari "Sedia Pickup" (`packed`) ke "Diambil" (`delivered`), tiada tracking. |
| Pesakit kata tak terima notifikasi | Notifikasi ditulis ke `psy_notifications` (link `orders.html`). Pastikan `patient_id` order betul. |
| Tersilap batalkan order yang dah dibungkus | Stok dipulangkan automatik (restock), tapi notifikasi "dibatalkan" sudah dihantar — maklum pesakit secara manual. |

---

## 8. Rujukan teknikal
- Page staf: [`roles/staff/orders.html`](../../../roles/staff/orders.html) · `markStatus()` ~ baris 469, `confirmShip()` ~ baris 558
- Page pesakit: [`roles/patient/orders.html`](../../../roles/patient/orders.html) · `confirmDelivered()` ~ baris 295
- Jadual: `psy_orders` (lifecycle paid→packed→shipped→delivered), `psy_products`, `psy_notifications`, `psy_audit_log` (lihat [02-pangkalan-data.md](../../sistem/02-pangkalan-data.md))
- Sync stok: [`shared/stockSync.js`](../../../shared/stockSync.js)
- Storage gambar parsel: bucket `order-photos`
