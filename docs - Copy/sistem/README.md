# Dokumentasi Sistem ISW Psikoterapi

**Ibnu Sina Wellness (ISW) — Sistem Psikoterapi & Wellness**
Dokumentasi rasmi sistem: gambaran ciri (feature overview) + dokumentasi teknikal (developer).

> Kemaskini terakhir: 24 Jun 2026
> Sumber kebenaran tunggal untuk struktur sistem. Bila ada percanggahan dengan dokumen lama, dokumen ini diutamakan.

---

## Apa itu sistem ISW?

Aplikasi web untuk menguruskan **program rawatan/wellness psikoterapi** Ibnu Sina Wellness — dari pengambilan pesakit (lead), onboarding (KYC + KOB), pelan rawatan mingguan, pemantauan kepatuhan harian, inventori & e-dagang, sehingga laporan & tadbir urus.

Dua jenis pengguna utama:

| Pengguna | Akses | Portal |
|----------|-------|--------|
| **Pesakit** | Onboarding, pelan rawatan, catatan harian, kedai, bayaran, surat | `roles/patient/` |
| **Staf** | Pentadbiran penuh — pesakit, pakej, inventori, laporan, automasi | `roles/staff/` |

Staf dibahagikan kepada 5 peranan: **super_admin, admin, manager, doctor, coach** (lihat [05 — Peranan & Akses](05-peranan-akses.md)).

---

## Indeks Dokumentasi

| # | Dokumen | Kandungan |
|---|---------|-----------|
| 00 | **README** (fail ini) | Ringkasan eksekutif, tech stack, struktur folder |
| 01 | [Seni Bina Teknikal](01-seni-bina.md) | Tech stack, struktur fail, `shared/*.js`, config/env, deploy |
| 02 | [Pangkalan Data](02-pangkalan-data.md) | Skema penuh (75+ jadual), pendekatan migrasi, projek Supabase |
| 03 | [Modul Sistem](03-modul.md) | Setiap modul ciri: fungsi, halaman, jadual, aliran |
| 04 | [Automasi & Edge Functions](04-automasi-edge.md) | Mesej automatik WhatsApp, cron, Edge Functions, GHL |
| 05 | [Peranan & Akses (RBAC)](05-peranan-akses.md) | Peranan staf, navigasi, authGuard, kebenaran granular |
| 06 | [Status & Roadmap](06-status-roadmap.md) | Status semasa, fasa rollout, kerja tertangguh |

Dokumen sokongan sedia ada (kekal relevan):
- [`docs/System_Flows.md`](../System_Flows.md) — rajah aliran ASCII setiap modul
- [`docs/Checklist_Penuh.md`](../Checklist_Penuh.md) — checklist A–Z status terperinci (~290 item)
- [`docs/Phase_Status_Roadmap_Jun2026.md`](../Phase_Status_Roadmap_Jun2026.md) — pelan fasa

---

## Tech Stack (ringkas)

| Lapisan | Teknologi |
|---------|-----------|
| Frontend | HTML statik + **Tailwind CSS (CDN)** + **vanilla JavaScript** (tiada framework/build step) |
| Backend / DB | **Supabase** (PostgreSQL + Auth + Storage + Row-Level Security) |
| Logik server | **Supabase Edge Functions** (Deno/TypeScript) |
| Automasi mesej | **GoHighLevel (GHL)** untuk WhatsApp/Email + cron `pg_cron` |
| PDF | `pdf-lib` (agreement, surat), cetak browser |
| Eksport | SheetJS (Excel), cetak browser (PDF) |
| Dwibahasa | Enjin i18n custom (BM ⇄ EN) — `shared/i18n.js` |
| Hosting | Vercel / Railway (static) — `vercel.json`, `railway.json`, `server.js` |

**Tiada build step** — fail HTML/JS dihidang terus. Setiap halaman muat `config/supabase.js` + pustaka shared melalui `<script>`.

---

## Struktur Folder (peringkat atas)

```
ISW system/
├── index.html, landing-preview.html, offline.html   # Pendaratan awam + offline PWA
├── auth/              # login, reset, set-password (+ auth.js)
├── roles/
│   ├── patient/       # 32 halaman pesakit
│   └── staff/         # 69 halaman staf
├── shared/            # 15 pustaka JS dikongsi (navbar, authGuard, i18n, dll)
├── config/            # supabase.js — env + helper DB
├── database/          # Skema kanonik (master_migration.sql + seeds.sql)
├── supabase/
│   ├── functions/     # 5 Edge Functions (Deno/TS)
│   └── migrations/    # Migrasi tambahan (auto-messages, kepatuhan alerts)
├── Agreement/         # 12 template PDF kontrak pakej
├── surat/             # Template surat rasmi (RELA, dll)
├── icon/, image/      # Aset
└── docs/              # Dokumentasi (termasuk folder sistem/ ini)
```

---

## Konsep Teras (untuk faham pantas)

1. **Pesakit** (`psy_patients`) ialah hab pusat — disambung ke `active_package_id`, `kob_status`, `assigned_coach_id`, `outcome_status`.
2. **Pakej** (`psy_packages`) tentukan tempoh rawatan, jadual bimbingan, bekalan, klausa kontrak.
3. **Pelan rawatan** dijana dari pakej → baris mingguan (`psy_plan_weekly_progress`) yang coach tanda hadir/batal.
4. **Auto-deduct stok**: sesi tanda hadir → tolak inventori automatik (`shared/inventoryDeduct.js`).
5. **Auto-sync**: Inventori ↔ Produk padan ikut nama (`shared/stockSync.js`).
6. **Audit**: setiap tindakan penting tulis ke `psy_audit_log` (`auditLog()` dalam config).
7. **RLS**: setiap jadual ada polisi — pesakit nampak baris sendiri, staf nampak semua (ikut peranan).
8. **Automasi**: satu Edge Function (`event-reminders`) jalankan 4 runner (reminder acara, broadcast, reminder catatan harian, alert kepatuhan) dipacu `psy_auto_messages` + cron.

Untuk detail penuh, mula dari [01 — Seni Bina Teknikal](01-seni-bina.md).
