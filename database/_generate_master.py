# -*- coding: utf-8 -*-
"""
Jana master_migration.sql daripada fail skema domain dalam database/schema/.
Jalankan: python database/_generate_master.py
Fail schema dijalankan ikut susunan nombor (00_, 01_, ... 24_).
"""
import os, datetime

DB = os.path.dirname(os.path.abspath(__file__))
SCHEMA = os.path.join(DB, "schema")

EXCLUDE = {"master_migration.sql", "drop_all.sql"}
files = sorted(f for f in os.listdir(SCHEMA) if f.endswith(".sql") and f not in EXCLUDE)

parts = [
    "-- ISW System — master_migration.sql",
    "-- DIJANA AUTOMATIK daripada database/schema/*.sql — JANGAN edit fail ini terus.",
    "-- Edit fail domain dalam database/schema/, kemudian jalankan: python database/_generate_master.py",
    "-- Generated: %sZ" % datetime.datetime.utcnow().isoformat(),
    "-- Jumlah fail: %d" % len(files),
    "-- Selamat dijalankan pada projek Supabase kosong (SQL Editor).",
    "",
]
for name in files:
    with open(os.path.join(SCHEMA, name), encoding="utf-8") as f:
        content = f.read().strip()
    parts.append("\n-- ════════════════════════════════════════════════════════════════")
    parts.append("-- schema/%s" % name)
    parts.append("-- ════════════════════════════════════════════════════════════════\n")
    parts.append(content + "\n")

out = os.path.join(DB, "master_migration.sql")
with open(out, "w", encoding="utf-8") as fh:
    fh.write("\n".join(parts))
print("OK: master_migration.sql dijana daripada %d fail schema/" % len(files))
