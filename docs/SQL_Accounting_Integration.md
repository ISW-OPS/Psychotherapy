# Integrasi SQL Accounting ⇄ ISW (Manual Trigger Sync)

> Sumber: one-pager asal "SQL Account → Supabase Sync (Manual Trigger)"
> bertarikh **9 Julai 2026**, status asal "For discussion". Digabung
> dengan pecahan 11-step & senarai komponen yang disediakan sama sesi.
> Status semasa (26 Ogos 2026): **belum mula coding**, masih peringkat
> requirement gathering — lihat Bahagian 8.

## 1. Objektif

Jadikan data kewangan SQL Accounting (On-Premise) boleh dicapai
**24/7** — walaupun PC/server On-Premise cuma hidup semasa waktu
pejabat — dengan cara **mirror** dataset kewangan penuh ke Supabase
secara **manual-triggered** (bukan auto/scheduled).

## 2. Setup semasa

- SQL Account jalan **On-Premise** pada PC dedicated. **Tiada rancangan
  upgrade ke SQL Account Cloud.**
- SQL Account API Service sudah enabled pada PC tu (port-forwarded,
  auth **AWS SigV4** via Access Key + Secret Key).
- PC & API **hanya online semasa waktu pejabat** — ini **boleh
  diterima** kerana tiada keperluan sync/panggilan selepas waktu
  pejabat.

## 3. Penyelesaian dicadangkan — kenapa Manual Trigger (bukan auto-sync)

Berbanding cron/scheduled sync yang perlukan PC on 24/7, pendekatan
ni:

1. Accountant **finalize** kemasukan hari tu dalam SQL Account
   (On-Premise).
2. Accountant klik **satu butang "Sync to Supabase"** (tool/shortcut
   ringkas dalam PC yang sama).
3. Script authenticate ke SQL Account API Service (AWS SigV4,
   Access+Secret Key, HTTPS port 443).
4. Script tarik (pull) dataset kewangan penuh melalui API.
5. Script transform/normalize rekod supaya match schema Supabase.
6. Script **upsert** ke Supabase, keyed pada ID stabil (**DocNo /
   dtlkey**) — selamat run berulang kali, tiada duplicate.
7. Setiap run di-log (timestamp, jumlah rekod, success/fail) + medan
   **"Last synced"** dikemaskini.
8. App/dashboard downstream **baca dari Supabase sahaja** — available
   24/7 tanpa kira status PC On-Premise.

Kelebihan: app/dashboard tak perlu bergantung PC On-Premise sentiasa
hidup — cukup accountant klik sync sekali sehari lepas books
finalized.

## 4. Data scope (dataset kewangan PENUH — bukan sebahagian)

Semua yang SQL Account API expose:

- Sales Invoices & Purchase Invoices
- Customer Payments & Supplier Payments
- GL (General Ledger) entries
- Rekod Customer & Supplier
- Stock Items

## 5. Arkitektur

```
INTERNET
   │
   ▼
Dedicated PC / Local Server
   SQL Accounting API Service
   │  (SQL Account API — AWS SigV4, port 443)
   ▼
Sync Service (Node.js / Python)
   pull → transform → upsert
   │
   ▼
Supabase
   Finance Data (schema berasingan)
```

**Point penting:** PC/server tu perlu **ON + internet available**
semasa sync dijalankan sahaja (bukan 24/7) — sebab trigger manual,
bukan scheduled.

## 6. Keselamatan & kawalan akses

- Butang sync **hanya untuk role accountant / authorized** — sebab ia
  effectively "publish" angka rasmi.
- Access Key & Secret Key SQL Account disimpan dalam secrets
  manager/env var pada PC — **jangan hardcode**.
- Supabase **service-role key** guna server-side sahaja dalam sync
  script — **jangan expose client-side**.
- **Row Level Security (RLS)** enabled pada mana-mana jadual Supabase
  yang dibaca oleh front-end/dashboard.
- Semua traffic encrypted in transit (HTTPS/TLS) — kedua-dua leg SQL
  Account API dan Supabase.
- Setiap sync run di-log untuk audit: siapa trigger, bila, jumlah
  rekod, outcome.

## 7. Risiko & mitigasi

| Risiko | Mitigasi |
|---|---|
| **Stale data** — Supabase cuma refleksi klik terakhir | Papar timestamp **"Last synced"** dengan jelas di mana-mana data tu digunakan |
| **Missed click** — accountant lupa sync | Tambah reminder hujung hari (end-of-day) supaya accountant tak lupa |
| **PC mesti ON untuk sync** | Sudah compatible dengan setup sedia ada (office-hours-only) |

## 8. 11-Step Rollout

| # | Step | Apa yang dibuat | Apa yang diperlukan |
|---|------|------------------|----------------------|
| 1 | Confirm SQL Account setup | Semak versi & database SQL Accounting | SQL Account + database |
| 2 | Prepare dedicated PC/server | PC yang menjalankan SQL Accounting/API | Windows PC/server |
| 3 | Enable SQL Account API Service | Install & configure API Service | SQL Account API Service |
| 4 | Create API credentials | Create API user & generate credentials | Access Key + Secret Key |
| 5 | Prepare network access | Pastikan API boleh dicapai | Stable Internet + Public IP + Port 443/port forwarding |
| 6 | Test API connection | Pastikan system boleh connect ke SQL Accounting | Postman / API testing tool |
| 7 | Confirm data scope | Tentukan data yang perlu diambil | Customer, Supplier, Invoice, Payment, GL, Stock dll. |
| 8 | Prepare Supabase | Sediakan database untuk financial data | Supabase project/schema + tables |
| 9 | Build sync service | Pull → transform → upsert | Backend/Node.js/Python + Supabase |
| 10 | UAT | Compare data dengan accountant | Test data + accountant validation |
| 11 | Go-live | Gunakan sync sebenar | Production credentials + monitoring/logging |

**Status:** baru di **Step 1** (verify SQL Account setup) — belum
disahkan oleh accountant/vendor.

## 9. Komponen/barang yang diperlukan

**SQL Accounting side:**
- SQL Accounting On-Premise
- Dedicated Windows PC/server
- SQL Account API Service
- API User
- Access Key
- Secret Key
- Stable Internet
- Public IP
- Port 443 / port forwarding

**Development side:**
- Backend/server untuk sync script
- Supabase (cadang plan **Pro**, ~US$25/bulan + usage — free tier
  **tak sesuai**: had 500MB, auto-pause selepas 7 hari idle, tak
  sesuai untuk "full financial dataset" + keperluan reliability harian)
- Postman untuk testing API
- Database schema/table untuk finance
- Logging mechanism

**People/access:**
- Accountant — untuk validate data & trigger sync
- IT/network person — untuk public IP & port forwarding
- Developer — untuk API + Supabase integration

## 10. Cost & anggaran masa (kasar, developer perlu confirm ikut kapasiti sebenar)

| Item | Anggaran |
|---|---|
| SQL Account | Tiada perubahan — kekal On-Premise, tiada fee upgrade Cloud |
| Supabase plan | Pro, ~US$25/bulan + usage |
| Dev effort | One-time build: schema + sync script + trigger UI + logging |

**Rough phasing:**
- Confirm API version/keys sudah enabled — segera
- Design schema Supabase untuk dataset kewangan penuh — beberapa hari
- Build sync script (pull → transform → upsert) + logging — ~1 minggu
- Build trigger button/UI + access control — 2-3 hari
- UAT dengan accountant, validate angka vs SQL Account, go-live —
  beberapa hari

## 11. Checklist keperluan minimum (untuk hantar kat accountant/vendor)

| # | Item | Status |
|---|------|--------|
| 1 | Versi SQL Account (minimum 5.2025.1038.875+) & Firebird (3.0.9+) | ⬜ belum disahkan |
| 2 | API Service enabled pada instalasi tu | ⬜ belum disahkan |
| 3 | PC/server dedicated mana yang jadi API host | ⬜ belum ditentukan |
| 4 | Public IP + port forwarding port 443 sudah setup | ⬜ belum |
| 5 | User API khas (APIUser) + Access Key/Secret Key sudah generate | ⬜ belum |
| 6 | Data scope disahkan (rujuk Bahagian 4 — dataset penuh) | ✅ sudah confirm dalam one-pager asal |
| 7 | Arah sync (SQL Account → Supabase sahaja, one-way) | ✅ sudah confirm — one-way, manual trigger |
| 8 | Frekuensi sync (manual, on-demand oleh accountant) | ✅ sudah confirm — bukan real-time/scheduled |

## 12. Langkah seterusnya untuk developer

1. Confirm versi/setup SQL Account API memenuhi keperluan (dah
   configured On-Premise ke belum).
2. Finalize senarai field/entity tepat untuk "dataset kewangan penuh".
3. Provision Supabase project (Pro plan) + design schema mirror.
4. Build & test sync script + trigger button end-to-end bersama
   accountant.

## 13. Nota

- Ini **belum ada kod/migration** dibina — dokumen ni pelan sahaja.
- Sync **satu hala** (SQL Account → Supabase); tiada tulis balik ke
  SQL Account dari ISW.
- Kalau kelak keperluan berubah (cth. perlu near-real-time atau
  dua-hala), kena re-evaluate arkitektur "manual trigger" ni — bukan
  reka sekarang untuk kes yang belum pasti berlaku.
