# Panduan Pengguna (SOP) — Sistem ISW

**Manual operasi langkah-demi-langkah** untuk staf & pesakit.
Berbeza dengan [`docs/sistem/`](../sistem/README.md) (dokumentasi teknikal untuk developer), folder ini menjawab soalan **"macam mana nak buat X?"** — buka page mana, klik butang mana, isi field apa.

> Kemaskini terakhir: 24 Jun 2026

---

## Cara guna dokumen ini

Setiap panduan ikut format yang sama:

1. **Tujuan** — bila guna flow ni
2. **Siapa boleh buat** — peranan yang dibenarkan
3. **Lokasi** — page + jalan navigasi
4. **Langkah** — step bernombor
5. **Field wajib vs pilihan** — apa MESTI isi, apa boleh skip
6. **Apa jadi lepas simpan** — kesan ke sistem (auto-stok, audit, dsb.)
7. **Masalah biasa** — error & penyelesaian

Tanda: **`*`** = field wajib. 🟢 = staf. 🔵 = pesakit.

---

## Indeks Panduan

### 🟢 Staf — Operasi
| Tugas | Panduan | Page |
|-------|---------|------|
| Tambah / edit pakej rawatan | [staff/tambah-pakej.md](staff/tambah-pakej.md) ✅ | `pakej-edit.html` |
| Pesakit baru (lead → KYC → KOB) | [staff/pesakit-kyc-kob.md](staff/pesakit-kyc-kob.md) ✅ | `patients.html`, `kyc-review.html` |
| Pelan mingguan & tanda hadir | [staff/pelan-mingguan.md](staff/pelan-mingguan.md) ✅ | `plan-week.html` |
| Kepatuhan (Catatan Harian) | [staff/kepatuhan.md](staff/kepatuhan.md) ✅ | `kepatuhan.html`, `kepatuhan-fill.html` |
| Inventori & kit prosedur | [staff/inventori.md](staff/inventori.md) ✅ | `inventory.html`, `kit-edit.html` |
| Produk & kedai | [staff/produk.md](staff/produk.md) ✅ | `product-edit.html` |
| Pesanan & tracking | [staff/pesanan.md](staff/pesanan.md) ✅ | `orders.html` |
| Pembayaran | [staff/pembayaran.md](staff/pembayaran.md) ✅ | `payment-admin.html` |
| Pengumuman & acara | [staff/pengumuman-acara.md](staff/pengumuman-acara.md) ✅ | `pengumuman-baru.html`, `events.html` |
| Mesej automatik WhatsApp | [staff/auto-mesej.md](staff/auto-mesej.md) ✅ | `auto-mesej.html` |
| Library & FAQ | [staff/library-faq.md](staff/library-faq.md) ✅ | `library-edit.html`, `library-faq-edit.html` |
| Surat rasmi | [staff/surat-rasmi.md](staff/surat-rasmi.md) ✅ | `surat-issue.html`, `surat.html` |
| Peranan, staf & kebenaran | [staff/peranan.md](staff/peranan.md) ✅ | `peranan.html`, `staff_management.html` |

### 🔵 Pesakit — Self-service
| Tugas | Panduan | Page |
|-------|---------|------|
| Isi borang KYC | [patient/kyc.md](patient/kyc.md) ✅ | `kyc.html` |
| Daftar pakej + KOB + agreement | [patient/daftar-pakej.md](patient/daftar-pakej.md) ✅ | `pakej.html`, `kob.html` |
| Bayar pakej | [patient/bayar.md](patient/bayar.md) ✅ | `payment.html` |
| Catatan Harian (check-in) | [patient/catatan-harian.md](patient/catatan-harian.md) ✅ | `kepatuhan.html`, `checkin.html` |
| Pelan rawatan & jadual harian | [patient/pelan-rawatan.md](patient/pelan-rawatan.md) ✅ | `plan.html`, `routine.html`, `vitals.html` |
| Beli produk, jejak pesanan, pulangan | [patient/kedai-pesanan.md](patient/kedai-pesanan.md) ✅ | `shop.html`, `orders.html`, `pulangan.html` |
| Lapor isu & maklum balas | [patient/lapor-isu.md](patient/lapor-isu.md) ✅ | `issue.html`, `feedback.html` |
| Rekod perubatan, surat, library | [patient/rekod-surat-library.md](patient/rekod-surat-library.md) ✅ | `rekod-perubatan.html`, `surat.html`, `library.html` |

> ✅ = siap · _italic_ = senarai kerja (belum ditulis)

---

## Rujukan silang

- Skema data & jadual: [`docs/sistem/02-pangkalan-data.md`](../sistem/02-pangkalan-data.md)
- Senarai modul & aliran: [`docs/sistem/03-modul.md`](../sistem/03-modul.md)
- Peranan & akses: [`docs/sistem/05-peranan-akses.md`](../sistem/05-peranan-akses.md)
- Rajah aliran ASCII: [`docs/System_Flows.md`](../System_Flows.md)
