# 📋 Readiness Plan — Patient Team (Phase 2)
> ISW System (Ibnu Sina Wellness) · Disediakan 30 Jun 2026
> Tujuan: sediakan sistem untuk **batch testing oleh pasukan/pesakit sebenar** sebelum go-live penuh.

---

## 1. OBJEKTIF
Membolehkan sekumpulan kecil pesakit sebenar (pilot) menggunakan portal pesakit dari hujung ke hujung — daftar, KYC, KOB, pelan rawatan, catatan harian, vitals, order, surat — sambil pasukan memantau, mengumpul maklum balas, dan membetulkan isu sebelum dibuka kepada semua pesakit.

**Kejayaan = ** pesakit pilot boleh selesaikan satu kitaran penuh (daftar → guna mingguan) tanpa bantuan teknikal, dan pasukan dapat semua data dalam dashboard staff.

---

## 2. SKOP PILOT (cadangan)
| Perkara | Cadangan |
|---|---|
| Bilangan pesakit pilot | 5–10 orang (campuran pakej & keadaan) |
| Tempoh | 2–3 minggu |
| Saluran | Web (desktop + mobile browser / PWA) |
| Persekitaran | **TESTING dahulu**, kemudian PROD bila stabil |
| Sokongan | 1 coach + 1 admin standby untuk bantu pesakit |

---

## 3. APA YANG DAH SEDIA UNTUK PESAKIT ✅
Portal pesakit ini **sudah berfungsi** dan boleh diuji:
- Daftar akaun + **KYC** (isi maklumat, tunggu kelulusan staff)
- **KOB** — lihat sesi, link Google Meet (online), cadangan pakej
- **Pelan rawatan** — lihat progres mingguan, skor
- **Catatan Harian** + **Kepatuhan** (checklist amalan harian)
- **Daily Check-in** (mood, tenaga, tidur, madu)
- **Vitals** — input BP/HbA1c sendiri + graf
- **Routine** — contoh jadual harian ikut pakej
- **Shop / Order** produk + jejak status
- **Surat** — mohon surat, muat turun PDF bila siap
- **Pulangan botol** · **Rekod perubatan** (upload)
- **Library** kandungan · **Pengumuman/Acara** · **FAQ** · **Feedback** · **Lapor isu**
- **Dwibahasa** BM⇄EN · **PWA** boleh install di telefon

## 4. APA YANG BELUM SEDIA (impak ke pesakit) 🟡
| Perkara | Kesan ke pesakit pilot | Penyelesaian sementara |
|---|---|---|
| **Payment gateway sebenar** | Bayar pakej/produk masih simulasi | Bayaran manual (transfer) + staff key-in |
| **WhatsApp automasi** | Tiada peringatan auto via WA | Coach ingatkan manual buat masa ini |
| **Mobile UI/UX polish** | Sesetengah page belum 100% kemas di telefon | Uji & senarai page bermasalah dahulu |
| **Chat pesakit↔coach dalam app** | Belum ada chat terus | Guna "Lapor Isu" (ada thread) atau WhatsApp biasa |

---

## 5. LANGKAH KESEDIAAN (sebelum pilot mula)

### A. Teknikal
- [ ] Sahkan semua page pesakit buka tanpa error (desktop + 1 telefon)
- [ ] Uji aliran penuh dengan **1 akaun pesakit ujian** dahulu
- [ ] Semak mobile: senarai page yang perlu dibaiki responsif
- [ ] Pastikan kelulusan KYC oleh staff berfungsi (notifikasi sampai)
- [ ] Sediakan akaun coach/admin sokongan
- [ ] Backup / tahu cara reset jika data rosak

### B. Proses & manusia
- [ ] Pilih 5–10 pesakit pilot + dapatkan persetujuan mereka
- [ ] Sediakan **panduan ringkas pesakit** (1 muka: cara daftar & guna)
- [ ] Tetapkan 1 orang "talian bantuan" pilot
- [ ] Tetapkan cara kumpul maklum balas (borang / WhatsApp group)
- [ ] Jadual check-in mingguan dengan pasukan

### C. Pemantauan semasa pilot
- [ ] Coach semak dashboard setiap hari (check-in %, kepatuhan, risiko)
- [ ] Log semua isu dilaporkan (page, langkah, screenshot)
- [ ] Mesyuarat mingguan: isu utama + keputusan baiki/teruskan

---

## 6. KRITERIA GO / NO-GO (selepas pilot)
**GO ke PROD penuh bila:**
- Tiada isu kritikal (pesakit tak boleh daftar / data hilang / page crash) berbaki
- ≥80% pesakit pilot boleh guna tanpa bantuan teknikal
- Dashboard staff tunjuk data tepat
- Keputusan dibuat untuk: **payment gateway** & **WhatsApp** (atau sahkan proses manual sementara diterima)

---

## 7. TIMELINE CADANGAN
| Minggu | Aktiviti |
|---|---|
| Minggu 0 (sebelum) | Langkah kesediaan A & B · pilih pesakit · panduan ringkas |
| Minggu 1 | Pesakit daftar + KYC + onboarding · pantau rapat |
| Minggu 2 | Guna harian penuh (check-in, vitals, pelan) · kumpul maklum balas |
| Minggu 3 | Baiki isu · ujian semula · mesyuarat Go/No-Go |
| Selepas | Keputusan go-live + plan rollout penuh |

---

## 8. KEPUTUSAN DITUNGGU DARIPADA MANAGEMENT
- Payment gateway: **Billplz atau ToyyibPay?** (atau terima bayaran manual untuk pilot)
- WhatsApp API: stack mana? (atau coach ingatkan manual untuk pilot)
- Siapa 5–10 pesakit pilot & bila mula?
- TESTING sahaja dulu, atau terus PROD untuk pilot?
