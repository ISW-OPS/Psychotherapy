# supabase/migrations

Folder untuk migrasi tambahan ke DB yang sedang hidup (testing/prod).

- Migrasi lama (semua sudah di-run di testing + prod, sehingga 20260717) telah dibuang —
  kandungannya sudah dilipat ke dalam `database/schema/` (rujuk `database/README.md`).
- Bila buat perubahan skema baru: edit fail domain `database/schema/`, jana semula master
  (`python database/_generate_master.py`), kemudian tulis fail migrasi kecil di sini
  (`YYYYMMDD_nama.sql`) berisi HANYA perubahan, dan run di Supabase SQL Editor.
