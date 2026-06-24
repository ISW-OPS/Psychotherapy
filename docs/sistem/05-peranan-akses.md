# 05 — Peranan & Akses (RBAC)

[← Kembali ke indeks](README.md)

Kawalan akses ada **dua lapisan**:
1. **UI/navigasi** — `shared/authGuard.js` + `shared/navbar.js` (sembunyi/sekat halaman).
2. **Data** — Row-Level Security (RLS) di PostgreSQL (lapisan sebenar yang lindungi data).

> Penting: UI guard sahaja TIDAK cukup untuk keselamatan. RLS yang menguatkuasakan akses data. Bila tambah modul/jadual baru, kemas kini KEDUA-DUA lapisan.

---

## 1. Jenis pengguna

`psy_profiles.role` = `patient` atau `staff`. Jika `staff`, `psy_profiles.staff_role` tentukan peranan:

| `staff_role` | Akses ringkas |
|--------------|---------------|
| `super_admin` | **Semua** — bypass semua semakan kebenaran |
| `admin` | Semua halaman + urus staf + audit + governance |
| `manager` | Pesakit, inventori, pesanan, pengumuman, laporan (kebanyakan *view*) |
| `doctor` | KYC, KOB, slot, pesakit |
| `coach` | Weekly plan, pesakit, kepatuhan, inventori, pulangan |

`super_admin` ada laluan pintas dalam `authGuard.js`:
```js
if (window.currentUser?.staff_role === 'super_admin') return true;
```

---

## 2. `authGuard.js` — cara ia berfungsi

- `window.PAGE_MODULE` = peta **id halaman → modul kebenaran**. Contoh: `assignments`, `coaching`, `consultation` → modul `'coaching'`.
- Bila halaman dibuka: jika `pageId` ada dalam `PAGE_MODULE`, semak `can(module, 'view')`. Jika tiada dalam peta (cth `profile`, `login`) → sentiasa benarkan.
- `can(module, action)` semak kebenaran pengguna (dari `psy_role_permissions` + override `psy_user_permissions`). `super_admin` sentiasa `true`.

Kebenaran disimpan dalam DB:
| Jadual | Guna |
|--------|------|
| `psy_roles` | Senarai peranan (super_admin, doctor, coach, dll) |
| `psy_modules` | Definisi modul sistem |
| `psy_role_module_actions` | Tindakan yang dibenarkan per peranan + modul |
| `psy_role_permissions` | Peta peranan → kebenaran (default) |
| `psy_user_permissions` | Override per-pengguna |

UI urus kebenaran: `S peranan.html` ("Peranan & Kebenaran") + `S audit-kebenaran.html`.

---

## 3. Navigasi pesakit (`navbar.js`)

Sidebar pesakit (`roles/patient/`):

| Label | Halaman |
|-------|---------|
| Dashboard | `dashboard.html` |
| KOB | `kob.html` |
| Pengumuman | `announcements.html` |
| Acara & Kelas | `events.html` |
| My Treatment Plan | `plan.html` |
| Jadual Harian | `routine.html` |
| Pakej Rawatan | `pakej.html` |
| Catatan Harian | `kepatuhan.html` |
| Bacaan Saya | `vitals.html` |
| Rekod Perubatan | `rekod-perubatan.html` |
| Self-Help Library (Video/Artikel/FAQ) | `library.html`, `faq.html` |
| Product | `shop.html` |
| Payment | `payment.html` |
| Orders & Tracking | `orders.html` |
| Report Issue | `issue.html` |
| Pulangan Botol | `pulangan.html` |
| Surat Rasmi | `surat.html` |
| KYC Form | `kyc.html` |

**Bottom tab bar (mobile pesakit):** Home · Plan · Catatan · Library · Profil.

---

## 4. Navigasi staf (`navbar.js`)

Sidebar staf dikumpul ikut kategori. Setiap item ada `id` modul yang diuji oleh `authGuard.js`:

### UTAMA
Dashboard · Pesakit (`patients.html`) · KYC (`kyc-list.html`) · Kalendar & Jadual (`appointments.html`) · Weekly Plan (`weekly-plan.html`) · Sesi KOB (`kob-list.html`) · Kepatuhan (`kepatuhan.html`) · Amaran Risiko (`risk.html`)

### OPERASI
Pakej Rawatan · Produk · Inventori · Orders & Tracking · Pulangan Botol · Pembayaran (`payment-admin.html`)

### KOMUNIKASI
Pengumuman · Acara & Kelas (`events.html`) · **Mesej Automatik** (`auto-mesej.html`) · Library

### LAPORAN
Governance · Statistik (`staff-stats.html`) · Laporan Pakej (`pakej-laporan.html`) · Report Issue

### PENTADBIRAN
Surat Rasmi · Penutupan Klinik (`closures.html`) · Slot Konsultasi (`kob-slots.html`) · Manage Staff (`staff_management.html`)

### SISTEM
Peranan & Kebenaran (`peranan.html`) · Audit Kebenaran (`audit-kebenaran.html`) · Audit Log (`audit.html`)

---

## 5. Audit

Setiap tindakan penting (simpan pakej, lulus KYC, laras stok, tukar status order, tandatangan agreement, jana surat) tulis ke `psy_audit_log` melalui helper `auditLog(action, target, meta)` dalam `config/supabase.js`. Dipapar & ditapis di `S audit.html` (actor / action / julat tarikh).

---

Seterusnya: [06 — Status & Roadmap →](06-status-roadmap.md)
