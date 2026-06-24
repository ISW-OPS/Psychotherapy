# 06 — Status & Roadmap

[← Kembali ke indeks](README.md)

Snapshot status sistem + fasa rollout + kerja tertangguh. Untuk checklist A–Z penuh (~290 item) lihat [`docs/Checklist_Penuh.md`](../Checklist_Penuh.md).

---

## 1. Saiz sistem (codebase)

| Komponen | Bilangan |
|----------|:--------:|
| Halaman pesakit | ~32 (`roles/patient/*.html`) |
| Halaman staf | ~69 (`roles/staff/*.html`) |
| Halaman auth | 3 (`login`, `reset`, `set-password`) |
| Pustaka shared JS | 15 (`shared/*.js`) |
| Jadual DB | ~75 (`psy_*`) |
| Edge Functions | 5 (`supabase/functions/`) |
| Template PDF agreement | 12 (`Agreement/`) |
| Template surat | 7 (+ RELA DOCX/PDF) |

---

## 2. Fasa rollout produk

> Ini fasa **produk**, jangan keliru dengan 3-fasa GHL.

| Fasa | Skop | Status |
|------|------|--------|
| **Fasa 1** | Web app MVP, semua peranan hujung-ke-hujung | ✅ Siap (live dalaman) |
| **Fasa 2** | Tutup jurang fungsi + **UI mobile (responsive web/PWA)** + ujian batch pesakit sebenar | 🟡 Sedang |
| **Fasa 3/4** | App mobile native **pesakit sahaja** (staf kekal web) | 🔴 Kemudian |

**Penemuan UI mobile:** stack = Tailwind CDN + vanilla JS + Supabase; halaman ada viewport meta + sebahagian `md:` breakpoints TAPI layout pesakit guna `<aside w-64 sticky h-screen>` yang **tak collapse** di mobile = penghalang utama. Pelan: sidebar → hamburger drawer (dalam `navbar.js`) + bottom tab bar pesakit + audit responsif per-halaman + **PWA wrapper** (manifest+SW) sebagai jambatan sebelum native.

Dokumen pelan: [`docs/Phase_Status_Roadmap_Jun2026.md`](../Phase_Status_Roadmap_Jun2026.md).

---

## 3. Modul SIAP (✅)

Platform foundation (auth/navbar/dashboard/theme) · KYC + KOB + agreement digital · Pakej + pelan rawatan mingguan · Penjadualan + cuti klinik + Google Meet · Catatan Harian + Kepatuhan (skor A/B/C + heatmap + eksport + staff-fill) · Vital + rekod perubatan · Inventori + auto-deduct + auto-sync + pulangan botol · Kedai + order lifecycle · Library + FAQ · Pengumuman + Acara & Kelas · Surat rasmi + isu produk · Pesakit + staf + RBAC + audit · Governance + risk + statistik · Inbox WhatsApp + Mesej Automatik (rangka) · Dwibahasa BM⇄EN.

---

## 4. Sedang berjalan / separa (🟡)

- **UI mobile responsive / PWA** — drawer + bottom bar + audit per-halaman.
- **Dwibahasa** — enjin + glosari siap; rollout per-halaman; string `${...}` dinamik tak boleh terjemah.
- **Automasi production** — runner siap di prod tapi `is_active` masih OFF; perlu assign coach + toggle.
- **Trend vital** — view jadual ada; graf trend belum.
- **Coach performance dashboard** — metrik per-coach belum.

---

## 5. Tertangguh / pending keputusan

| Item | Tunggu |
|------|--------|
| **Payment gateway sebenar** | Pilih Billplz vs ToyyibPay + kad + SST (bincang Zahin). `processPayment()` masih simulasi. |
| **GHL integration penuh** | GHL location/calendar IDs dari user; rotate-watch token |
| **Kepatuhan: target/item per fasa** | Hanya Week 1 ada item seeded; perlu target madu + ambang A/B/C + item set fasa lain |
| **Risk alert kriteria** | Sebahagian dibuka via runner kepatuhan; kriteria penuh tunggu Izzah |
| **Ujian batch pesakit** | Pilih env staging berasingan vs flag `is_test_account` |
| **WhatsApp Business API / aliran 2-hala** | Fasa 2 |
| **SQL Accounting connect** | Spec integrasi |

---

## 6. Keputusan/aturan penting yang sudah dimuktamadkan

- **Ketidakhadiran** (24 Jun 2026): coach tanda Tidak Hadir = absen + tawar reschedule **sahaja**; minggu tambahan berbayar dibuka **MANUAL**, tiada auto-caj.
- **Skor kepatuhan** = "Pilihan B" (Σ skor harian ÷ hari berlalu); A≥85 / B 50–84 / C<50.
- **Catatan Harian** ganti Google Form — isi harian dalam app.
- **Alert kepatuhan coach** = `inapp` sahaja (email dimatikan).
- **Penugasan** digabung ke `patients.html` (`assignments.html` bersara).
- **Dwibahasa** default English, sumber HTML kekal BM.

---

## 7. Rujukan memori projek (konteks penuh)

Untuk butiran setiap topik, rujuk fail memori (indeks: `MEMORY.md`):

| Topik | Memori |
|-------|--------|
| Mesej automatik + 4 runner | `project_auto_messages` |
| Modul kepatuhan | `project_kepatuhan_module` |
| Struktur skema DB | `project_db_schema_structure` |
| Dwibahasa | `project_i18n_bilingual` |
| GHL integration | `project_ghl_integration` |
| Aturan ketidakhadiran | `project_absence_extension_rule` |
| Roadmap fasa | `project_phase_roadmap` |
| Payment gateway | `project_payment_gateway_pending` |
| Pencegahan duplikat pesakit | `project_patient_dedup` |
| Penugasan digabung | `project_assignments_merged` |
| Modul library | `project_library_module` |
| Rekod perubatan | `project_medical_records` |

---

[← Kembali ke indeks](README.md)
