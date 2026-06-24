# 02 — Pangkalan Data (Database)

[← Kembali ke indeks](README.md)

PostgreSQL di Supabase. Semua jadual berprefiks `psy_`. RLS dihidupkan pada hampir semua jadual.

---

## 1. Struktur fail skema (PENTING untuk developer)

Skema kanonik ada di **`database/`** — bukan di `supabase/migrations/`.

| Fail | Guna |
|------|------|
| `database/master_migration.sql` | **SEMUA** DDL skema dalam susunan dependensi |
| `database/seeds.sql` | Data rujukan / default (klausa agreement, katalog, seed auto-mesej, dll) |
| `database/part1_step01_10.sql` → `part4_step31_end.sql` | Skema sama dipecah untuk had saiz SQL Editor |
| `database/drop_all.sql` | Padam semua (reset) |

**Cara pasang projek baru:** jalankan **master** ATAU **part1→part4**, kemudian **seeds.sql** terakhir.

### ⚠️ Gotcha pembangun
Fail sumber `step*.sql` **TIADA dalam repo** (hanya output dijana). Maka `python database/_generate_master.py` akan **skip semua**. Untuk tambah skema baru:
> **Edit `master_migration.sql` (dan `part4`) terus** + tambah baris seed ke `seeds.sql`. JANGAN bergantung pada generator.

Guna kenyataan idempotent: `create table if not exists`, `add column if not exists`, `drop/create policy`.

### `supabase/migrations/`
Folder migrasi tambahan untuk perubahan terkini (auto-messages, kepatuhan alerts). Migrasi yang sudah stabil dilipat masuk ke `database/master_migration.sql`. Bila tambah migrasi baru di sini, ingat untuk **fold balik** ke master supaya `database/` kekal sumber kebenaran.

---

## 2. Projek Supabase

| Env | Project Ref | Nota |
|-----|-------------|------|
| **Production** | `xmvqvqrifhwoehdfsoau` | TIADA akses MCP — user jalankan SQL & deploy manual di Dashboard |
| **Testing** | `ipmemyizigwgivccytcu` ("ISW Data Centre") | Akses MCP ada; localhost guna ini |

Konfigurasi di `config/supabase.js`. Sentiasa uji di testing dahulu sebelum apply ke production.

---

## 3. Senarai jadual ikut domain

> ~75 jadual. Dikumpulkan ikut fungsi. Rujuk `master_migration.sql` untuk lajur penuh + RLS.

### Identiti, Peranan & Audit
| Jadual | Guna |
|--------|------|
| `psy_profiles` | Profil pengguna (sambung ke auth.uid); `role` (patient/staff) + `staff_role` |
| `psy_permissions` | Definisi kebenaran (modul + tindakan) |
| `psy_role_permissions` | Peta peranan → kebenaran |
| `psy_user_permissions` | Override kebenaran per-pengguna |
| `psy_audit_log` | Log audit setiap tindakan penting (actor, action, target, meta) |

### Pesakit & Onboarding
| Jadual | Guna |
|--------|------|
| `psy_patients` | **Hab pusat** — `active_package_id`, `kob_status`, `assigned_coach_id`, `outcome_status` |
| `psy_kyc_submissions` | Borang KYC (biodata, kesihatan, alahan, kecemasan, pewaris/proxy) |
| `psy_kob_sessions` | Sesi KOB (Konsultasi Online Bermula) — soal selidik + saranan pakej |
| `psy_kob_agreements` | Kontrak digital ditandatangan + URL PDF |
| `psy_kob_slot_config` | Konfigurasi slot konsultasi |
| `psy_referrals` | Program rujukan pesakit |
| `psy_dna_reports` | Laporan Did-Not-Attend (tak hadir KOB) |

### Pakej & Pelan Rawatan
| Jadual | Guna |
|--------|------|
| `psy_packages` | Pakej rawatan — tempoh, `coaching_schedule`, `daily_schedule`, `agreement_clauses`, bekalan, harga |
| `psy_package_purchases` | Rekod pembelian pakej |
| `psy_package_categories` | Kategori pakej |
| `psy_treatment_plans` | Pelan rawatan per-pesakit (current_week, nama program) |
| `psy_plan_weekly_progress` | Baris setiap minggu × sesi (status: hadir/batal/dll) |
| `psy_plan_check_ins` | Check-in berkait pelan |
| `psy_plan_compliance` | Pematuhan pelan |

### Jadual, Temujanji & Coaching
| Jadual | Guna |
|--------|------|
| `psy_appointments` | Temujanji (harian/mingguan, reschedule) |
| `psy_clinic_closures` | Cuti/penutupan klinik (auto-lock kalendar) |
| `psy_slot_date_overrides` | Override slot ikut tarikh |
| `psy_coaching_sessions` | Sesi coaching |
| `psy_coaching_catalog` | Katalog bimbingan (boleh guna semula dalam pakej) |

### Kepatuhan, Check-in & Vital
| Jadual | Guna |
|--------|------|
| `psy_daily_checkins` | Daily check-in (emosi, tidur, aktiviti, madu, simptom) |
| `psy_daily_completions` | Log selesai aktiviti rutin harian |
| `psy_kepatuhan_item` | Config item checklist ikut fasa (`aktif`, `berskor`, `meta`, `jenis_input`) |
| `psy_kepatuhan_log` | 1 baris = 1 hari (`jawapan` jsonb, `skor`, `kelas`, override) |
| `psy_kepatuhan_weekly` | Ringkasan mingguan + override coach + nota |
| `psy_vitals` | BP / HbA1c (pesakit update sendiri; `reading_date`) |
| `psy_risk_alerts` | Amaran risiko (termasuk kategori `kepatuhan` auto) |
| `psy_adherence_alerts` | Amaran kepatuhan |

### Inventori, Produk & E-dagang
| Jadual | Guna |
|--------|------|
| `psy_inventory_items` | Master inventori (semua bekalan fizikal) |
| `psy_inventory_requests` | Permintaan/PO inventori |
| `psy_procedure_kits` | Kit prosedur (cth IV setup) |
| `psy_supply_disbursements` | Pengeluaran bekalan |
| `psy_products` | Produk untuk jualan (subset inventori, sync ikut nama) |
| `psy_services` | Perkhidmatan |
| `psy_orders` | Pesanan kedai (lifecycle: paid→packed→shipped→delivered) |
| `psy_bottle_returns` | Pulangan botol madu (reward/credit) |

### Kewangan
| Jadual | Guna |
|--------|------|
| `psy_payments` | Pembayaran (pakej/order/top-up); UI siap, gateway sebenar masih pending |

### Kandungan, Acara & Komunikasi
| Jadual | Guna |
|--------|------|
| `psy_library_items` | Item perpustakaan (media_type/topic/tags/package_ids) |
| `psy_library_categories` | Kategori perpustakaan |
| `psy_library_bookmarks` | Bookmark pesakit |
| `psy_library_feedback` | Maklum balas kandungan |
| `psy_library_views` | Tracking tontonan |
| `psy_announcements` | Pengumuman (sasaran: semua/pakej/staff; tarikh tamat papar) |
| `psy_announcement_categories` | Kategori pengumuman (urus dalam app) |
| `psy_announcement_types` | Jenis pengumuman |
| `psy_events` | Acara & kelas |
| `psy_event_registrations` | Pendaftaran + kehadiran acara |
| `psy_event_materials` | Bahan acara (nota/video/slaid/pautan) |
| `psy_notifications` | Notifikasi dalam app (loceng) |
| `psy_feedback` | Maklum balas am |
| `psy_weekly_feedback` | Maklum balas mingguan pesakit |
| `psy_auto_messages` | **Konfig mesej automatik** (template+masa+toggle) — pacu Edge Function |
| `psy_wa_conversations` | Perbualan WhatsApp (inbox GHL) |
| `psy_wa_messages` | Mesej WhatsApp individu |

### Surat, Rekod & Dokumen
| Jadual | Guna |
|--------|------|
| `psy_letter_requests` | Permohonan surat rasmi |
| `psy_letter_issued` | Surat dikeluarkan |
| `psy_letter_templates` | Template surat |
| `psy_letter_template_overrides` | Override template |
| `psy_letter_template_files` | Fail PDF template |
| `psy_letter_auto_fields` | Medan auto-isi surat |
| `psy_medical_reports` | Laporan perubatan (X-Ray/MRI/CT) muat naik pesakit/coach |
| `psy_medical_report_comments` | Komen laporan perubatan |
| `psy_patient_notes` | Nota pesakit (staf) |
| `psy_patient_documents` | Dokumen pesakit |

> Nota: jadual isu produk (`psy_issues`) wujud dan digunakan oleh modul Isu/Pulangan walaupun tak tersenarai dalam `create table` master ringkasan di atas — semak master untuk DDL tepat.

---

## 4. Hubungan teras (ER ringkas)

```
auth.uid → psy_profiles → psy_patients (hab)
                              ├── psy_kyc_submissions
                              ├── psy_kob_sessions / psy_kob_agreements
                              ├── psy_treatment_plans → psy_plan_weekly_progress
                              ├── psy_daily_checkins / psy_kepatuhan_log
                              ├── psy_vitals / psy_medical_reports
                              └── active_package_id → psy_packages
                                                         └── supplies → psy_inventory_items
                                                                            └── (sync nama) → psy_products → psy_orders
psy_audit_log ← setiap tindakan penting
```

Rajah aliran penuh: [`docs/System_Flows.md`](../System_Flows.md).

---

## 5. Petua nota penting

- **Jenis `active_package_id`**: di `psy_patients` ia **TEXT** (cth slug `'pkg-obpx1'`) manakala `psy_packages.id` ialah **UUID**. Join perlu cast; ada fallback dalam Edge Function bila tak padan.
- **RLS corak**: pesakit → baris sendiri sahaja; staf → semua (ikut `staff_role`). Bila tambah jadual baru, ingat tambah polisi staf (`FOR ALL` role=staff) supaya UI staf boleh tulis.
- **Idempotency**: semua DDL guna `if not exists` / `drop+create policy` supaya selamat dijalankan semula.

---

Seterusnya: [03 — Modul Sistem →](03-modul.md)
