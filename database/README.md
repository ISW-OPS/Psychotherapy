# Database ISW — Struktur & Cara Kerja

## Struktur

```
database/
├── schema/                  ← SUMBER KEBENARAN skema (edit di sini)
│   ├── 02_profiles_staff.sql
│   ├── 03_rbac_security.sql
│   ├── 04_patients.sql
│   ├── ...                  (satu fail per domain, susunan nombor = urutan run)
│   └── 24_storage.sql
├── master_migration.sql     ← DIJANA dari schema/ — jangan edit terus
├── _generate_master.py      ← penjana master
├── seeds.sql                ← data rujukan (run selepas master)
├── seeds_demo_*.sql         ← data demo
└── archive/                 ← fail step/part lama (sejarah, jangan run)

supabase/migrations/         ← migrasi tambahan (deploy ke DB sedia ada / prod)
```

## Setup projek Supabase BARU (DB kosong)

Run `master_migration.sql` penuh dalam SQL Editor, kemudian `seeds.sql`.
(Atau run fail `schema/*.sql` satu-satu ikut nombor.)

## Bila buat DEVELOPMENT BARU (ubah skema)

1. **Edit fail domain** berkaitan dalam `database/schema/` — kekalkan gaya bersih:
   kolum baru terus masuk `CREATE TABLE` (BUKAN tambah `ALTER TABLE` di bawah),
   polisi/fungsi ubah terus pada definisinya.
2. **Jana semula master**: `python database/_generate_master.py`
3. **Untuk DB sedia ada (testing/prod)**: tulis migrasi kecil berasingan dalam
   `supabase/migrations/YYYYMMDD_nama.sql` berisi HANYA perubahan
   (`ALTER TABLE ADD COLUMN ...` dll.) dan run di Supabase.

> Prinsip: `schema/` sentiasa gambaran keadaan AKHIR yang bersih;
> `supabase/migrations/` ialah sejarah perubahan untuk DB yang dah hidup.

## Nota gaya fail schema/

- Semua statement idempotent: `CREATE TABLE IF NOT EXISTS`, `CREATE OR REPLACE FUNCTION`,
  `DROP POLICY IF EXISTS` + `CREATE POLICY`, `CREATE INDEX IF NOT EXISTS`, seed dengan `ON CONFLICT`.
- Jangan tinggalkan `ALTER TABLE ADD COLUMN` dalam schema/ — lipat masuk CREATE TABLE.
- Komen ringkas BM; tiada komen sejarah ("ditambah step X").
- Urutan nombor fail menjaga dependency FK (contoh: `04_patients` sebelum jadual yang rujuk pesakit).
