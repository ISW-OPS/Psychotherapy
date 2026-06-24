# Panduan: Peranan & Kebenaran (RBAC), Urus Staf & Audit 🟢

[← Kembali ke indeks panduan](../README.md)

---

## 1. Tujuan
Kawal **siapa boleh buat apa** dalam sistem ISW. Tiga tugas berkaitan:
- **Peranan & Kebenaran (RBAC)** — tetapkan kebenaran modul (lihat/cipta/edit/padam) untuk setiap peranan, dan buat *override* khas untuk individu tertentu.
- **Manage Staff** — daftar akaun staf baru, tetapkan peranan mereka, edit/nyahaktif/padam.
- **Audit** — baca log siapa ubah apa (kebenaran, peranan, dan tindakan operasi).

> Sistem guna **5 peranan staf**: `super_admin` (bypass semua), `admin`, `manager`, `doctor`, `coach`. authGuard guna peta `PAGE_MODULE` → `can(module, action)` untuk benarkan/sekat setiap halaman. (Lihat [Peranan & Akses](../../sistem/05-peranan-akses.md).)

## 2. Siapa boleh buat
| Tugas | Peranan dibenarkan |
|-------|--------------------|
| **Peranan & Kebenaran** (`peranan.html`) | **`super_admin` SAHAJA** — page block semua peranan lain dan halau ke dashboard |
| **Audit Kebenaran** (`audit-kebenaran.html`) | **`super_admin` SAHAJA** |
| **Manage Staff** (`staff_management.html`) | Staf dengan kebenaran modul **`staff`** — biasanya `super_admin`, `admin`. Butang "Tambah/Edit/Padam" muncul ikut `can('staff','create'/'edit'/'delete')` |
| **Audit Log** (`audit.html`) | Staf dengan kebenaran modul **`audit`** |

## 3. Lokasi
Semua di sidebar staf bawah kategori **PENTADBIRAN** dan **SISTEM**:
- **Peranan & Kebenaran:** Sidebar → **SISTEM → Peranan & Kebenaran** (`roles/staff/peranan.html`)
- **Audit Kebenaran:** Sidebar → **SISTEM → Audit Kebenaran** (`roles/staff/audit-kebenaran.html`)
- **Audit Log:** Sidebar → **SISTEM → Audit Log** (`roles/staff/audit.html`)
- **Manage Staff:** Sidebar → **PENTADBIRAN → Manage Staff** (`roles/staff/staff_management.html`)
  - Edit satu staf: klik baris staf → buka `roles/staff/staff-detail.html?id=...`

---

## 4. Langkah ringkas

### A. Set kebenaran modul untuk satu peranan
1. Buka **Peranan & Kebenaran**. Senarai peranan di kiri.
2. Klik peranan (cth **Coach**) → matriks **Modul × Aksi** muncul di kanan.
3. **Klik kotak** dalam matriks untuk toggle (hijau ✓ = dibenarkan, kosong = tidak).
4. Klik **💾 Simpan Perubahan**. (Butang aktif hanya bila ada perubahan; tunjuk bilangan, cth "💾 Simpan (3 perubahan)".)

> Matriks **Super Admin terkunci** (sentiasa semua ✓) — ia bypass semua semakan, tak boleh diubah.

### B. Override kebenaran per-pengguna
1. Dalam page yang sama, pilih peranan pengguna itu dahulu (supaya default role dimuat).
2. Skrol ke **"Pengguna dalam peranan ini"** → klik nama pengguna.
3. Modal override buka — **klik kotak** untuk *kitar*: dari default → grant tambahan **atau** sekat (revoke) → kembali default.
4. Override **disimpan serta-merta** (tiada butang simpan berasingan). Klik **Selesai**.

> Hijau biasa = ikut default role · hijau berkilau = **grant tambahan** · merah ✕ = **disekat**. Butang **Buang Semua Override** kosongkan semua override individu.

### C. Tambah & urus staf, tetapkan peranan
1. Buka **Manage Staff** → **+ Tambah Staff**.
2. Isi **Staff ID, Name, Email**, pilih **Option** (Email Invite atau Set password), pilih **Staff Role**.
3. Klik **Daftar**. Untuk edit: klik baris staf → ubah di `staff-detail.html` → **Simpan**.

### D. Baca audit log
1. **Audit Kebenaran** untuk perubahan RBAC; **Audit Log** untuk tindakan operasi.
2. Tetapkan **Dari/Hingga**, pilih **Jenis Aktiviti** / **Modul** / **Aktor**, klik **🔍 Tapis**.

---

## 5. Field — wajib vs pilihan

### Borang "Daftar Staff Baru" (Manage Staff)
| Field | Wajib? | Nota |
|-------|--------|------|
| **Staff ID** `*` | ✅ **WAJIB** | Disimpan sebagai `registration_no`. Mesti unik — sistem block kalau dah wujud. Cth: `STF-001` |
| **Name** `*` | ✅ **WAJIB** | Nama penuh staf |
| **Email** `*` | ✅ **WAJIB** | Emel log masuk (jadi pengguna auth) |
| **Option** | Default `Email Invite` | `Email Invite (auto)` = sistem hantar jemputan set kata laluan · `Set password` = anda set terus |
| Password | Wajib bila Option = Set password | Min **6 aksara**. Staf boleh tukar dari Profil kemudian |
| **Staff Role** `*` | ✅ **WAJIB** | Senarai dari `psy_roles` aktif. **`super_admin` SENGAJA tak disenaraikan** — assign via SQL sahaja untuk keselamatan |

### Borang Edit Staf (`staff-detail.html`)
| Field | Nota |
|-------|------|
| Staff ID / Name / Email | Kemaskini maklumat asas |
| **Staff Role** | Tukar peranan staf (dropdown) |
| **Status** (Aktif/Tidak Aktif) | `is_active` — Tidak Aktif = staf tak boleh akses sistem |
| Jabatan / Specialization | Pilihan; dipapar dalam jadual |

### Modal "Peranan Baru / Edit Peranan" (RBAC)
| Field | Wajib? | Nota |
|-------|--------|------|
| **Kod** `*` | ✅ **WAJIB** | Huruf kecil + underscore sahaja (`^[a-z_]+$`). **Tak boleh diubah** selepas dicipta. Cth: `receptionist` |
| **Nama Paparan** `*` | ✅ **WAJIB** | Cth: `Receptionist` |
| Penerangan | Pilihan | Penerangan ringkas peranan |
| Ikon / Warna | Pilihan | Ikon emoji + warna chip (navy/purple/teal/green/gold/terracotta) |

### Matriks Kebenaran
- **Lajur = Aksi** (cth Lihat / Cipta / Edit / Padam — dari `psy_actions`).
- **Baris = Modul** (cth `patient`, `package`, `inventory`, `staff`, `audit` — dari `psy_modules`).
- Kotak **"—"** = aksi itu **Tidak Berkenaan** untuk modul tersebut (tak boleh diklik).
- Peranan `patient` papar modul scope pesakit sahaja (`pat_*`); peranan staf papar modul bukan-pesakit.

### Filter Audit Kebenaran
| Field | Nota |
|-------|------|
| Dari / Hingga | Julat tarikh (default 30 hari terakhir) |
| Jenis Aktiviti | grant/revoke (role), user grant/revoke, clear override, tukar peranan, cipta/edit/padam/aktif/nyahaktif peranan |
| Modul | Tapis ikut modul tertentu |
| Carian Aktor | Email/nama staf yang buat tindakan |

---

## 6. Apa jadi lepas Simpan

### Set kebenaran peranan (matriks)
1. Kebenaran ditulis ke **`psy_role_module_actions`** (insert untuk grant, delete untuk revoke).
2. Setiap perubahan dicatat ke **`psy_permission_audit`** (action `grant`/`revoke`, target = peranan).
3. **Berkuat kuasa serta-merta** untuk semua pengguna dalam peranan itu (pada log masuk seterusnya / muat semula kebenaran).

### Override per-pengguna
1. Ditulis ke **`psy_user_overrides`** (`grant_type` = `grant` atau `revoke`), atau dipadam bila kembali ke default.
2. Dicatat ke `psy_permission_audit` (action `user_grant`/`user_revoke`/`user_clear_override`).
3. Kebenaran berkesan dikira gabungan role default + override (lihat view `psy_user_effective_permissions`).

### Daftar staf
1. Akaun dicipta melalui **Edge Function `invite-staff`** (action `create`) — buat pengguna auth + rekod di `psy_profiles` (role = `staff`, `staff_role`, `registration_no`).
2. Jika "Email Invite" → emel jemputan dihantar; jika "Set password" → kata laluan ditetapkan terus.
3. Tindakan dicatat ke `psy_audit_log` (cth `staff.invited`, `staff.updated`, `staff.deleted`).
4. Senarai staf dimuat semula.

### Tukar peranan / status staf
- `staff_role` / `is_active` dikemaskini dalam `psy_profiles`; dicatat ke audit. Staf "Tidak Aktif" tak boleh log masuk guna sistem.

---

## 7. Masalah biasa
| Mesej / gejala | Sebab & penyelesaian |
|----------------|----------------------|
| "Halaman ini hanya untuk Super Admin." (lalu dihalau ke dashboard) | `peranan.html` & `audit-kebenaran.html` **super_admin sahaja**. Guna akaun super_admin. |
| Butang "+ Tambah Staff" / Edit / Padam tak muncul di Manage Staff | Tiada kebenaran modul `staff` (create/edit/delete). Minta super_admin grant di RBAC. |
| Matriks Super Admin tak boleh diklik | **Normal** — super_admin sentiasa ada semua kebenaran (terkunci). |
| "Staff ID sudah didaftarkan" | `registration_no` mesti unik. Guna ID lain. |
| "Nama dan email wajib diisi" / "Sila pilih Staff Role" | Lengkapkan field wajib `*` sebelum Daftar. |
| "Kata laluan mestilah min 6 aksara" | Option = Set password perlu kata laluan ≥ 6 aksara. |
| Tak nampak `super_admin` dalam dropdown daftar staf | **Sengaja** — assign super_admin via SQL sahaja untuk keselamatan. |
| "Tidak boleh padam — N pengguna masih guna peranan ini" | Ubah peranan pengguna tersebut dahulu sebelum padam peranan. |
| Peranan sistem tak boleh dipadam/nyahaktif | Peranan `is_system` (cth super_admin) dilindungi. Hanya peranan tambahan boleh dipadam. |
| Butang "Simpan Perubahan" (matriks) disabled | Tiada perubahan belum-simpan. Klik kotak dahulu. |
| Override tak nampak walau dah set | Pastikan peranan betul dipilih dahulu (default role mesti dimuat untuk kira override). |

---

## 8. Rujukan teknikal
- Page: [`roles/staff/peranan.html`](../../../roles/staff/peranan.html) — `saveMatrix()`, `cycleOverride()`, `saveRole()`
- Page: [`roles/staff/staff_management.html`](../../../roles/staff/staff_management.html) (senarai + daftar) · [`roles/staff/staff-detail.html`](../../../roles/staff/staff-detail.html) (edit) — guna Edge Function `invite-staff`
- Page: [`roles/staff/audit-kebenaran.html`](../../../roles/staff/audit-kebenaran.html) (RBAC) · [`roles/staff/audit.html`](../../../roles/staff/audit.html) (operasi)
- Guard: [`shared/authGuard.js`](../../../shared/authGuard.js) — `PAGE_MODULE`, `can(module, action)`, `loadPermissions()`
- Jadual: `psy_roles`, `psy_modules`, `psy_actions`, `psy_module_actions`, `psy_role_module_actions`, `psy_user_overrides`, view `psy_user_effective_permissions`; audit RBAC `psy_permission_audit`; audit operasi `psy_audit_log` (lihat [02-pangkalan-data.md](../../sistem/02-pangkalan-data.md))
- Konsep RBAC penuh: [05-peranan-akses.md](../../sistem/05-peranan-akses.md)
