# Integrasi SQL Accounting ⇄ ISW

Dokumen keperluan & pelan pelaksanaan untuk sambungkan ISW system dengan
**SQL Accounting** (versi **On-Premise** yang digunakan syarikat — bukan
cloud-hosted). Status semasa: **belum mula coding**, masih peringkat
kumpul keperluan (requirement gathering) daripada accountant/vendor.

## 1. Kenapa perlu integrasi ni

- Elak **duplicate key-in** — data invoice/payment/stock kena masuk dua
  kali (SQL Accounting + ISW) sekarang.
- Manager nak data kewangan (invoice, payment, stock, GL) refleksi
  dalam ISW system supaya staff/management tak perlu buka dua sistem.

## 2. Kenapa On-Premise beza dari cloud

SQL Accounting versi cloud (SQL Account Online) ada API terus boleh
capai dari internet tanpa setup tambahan. Versi **On-Premise** yang
syarikat guna:

- Jalan pada PC/server dedicated di premise sendiri (bukan hosted
  vendor).
- Untuk API boleh dicapai dari luar (contohnya oleh Supabase Edge
  Function), **PC/server tu sendiri kena jadi API server** — hidupkan
  "SQL Account API Service", buka port 443, dan buat port forwarding
  di router supaya ada public IP yang boleh sampai ke PC tu.
- Ini bermakna PC tu **kena hidup & online 24/7** (atau sekurangnya
  semasa waktu sync dijalankan), dan community/IT syarikat kena jaga
  keselamatan rangkaian (firewall, port forwarding betul, bukan expose
  cara tak selamat).

## 3. Keperluan minimum (checklist untuk accountant/vendor SQL Account)

Sebelum apa-apa coding boleh mula, kena confirm perkara ini:

| # | Item | Status |
|---|------|--------|
| 1 | Versi SQL Account (minimum **5.2025.1038.875+**) | ⬜ belum disahkan |
| 2 | Firebird database versi (minimum **3.0.9+**) | ⬜ belum disahkan |
| 3 | "SQL Account API Service" enabled pada instalasi tu | ⬜ belum disahkan |
| 4 | PC/server dedicated mana yang akan jadi API host | ⬜ belum ditentukan |
| 5 | Public IP + port forwarding port 443 ke PC tu sudah setup | ⬜ belum |
| 6 | User API khas dicipta (cth. `APIUser`) — jangan guna akaun staff biasa | ⬜ belum |
| 7 | Access Key + Secret Key (AWS SigV4 auth) sudah generate untuk `APIUser` | ⬜ belum |
| 8 | Data scope — modul/table mana nak sync (invoice? payment? stock? GL?) | ⬜ belum confirm dengan manager |
| 9 | Arah sync — SQL Accounting → ISW sahaja, atau dua-hala? | ⬜ belum confirm |
| 10 | Frekuensi sync — real-time, setiap X minit, atau manual trigger? | ⬜ belum confirm |

> **Nota keselamatan:** Access Key & Secret Key **hanya** disimpan di
> backend/sync server (cth. Supabase Edge Function secret) — jangan
> sekali-kali letak dalam kod frontend atau repo.

## 4. Data flow dicadangkan

```
SQL Accounting (On-Premise, PC dedicated)
   │  API Service (port 443, Access+Secret Key / AWS SigV4)
   ▼
Sync script (Node.js/Python, jalan sebagai backend/cron)
   │  authenticate → get data → transform → validate
   ▼
Supabase — schema BARU "finance" (berasingan dari "public")
   customers / suppliers / invoices / payments / stock / gl
   ▼
ISW system (baca dari schema finance)
```

- Arah asal dicadang: **SQL Accounting → Supabase → ISW** (tarik data
  kewangan masuk ISW, bukan tulis balik ke SQL Accounting). Kena
  confirm dengan manager kalau sebenarnya perlu dua-hala.
- Guna **DocNo / dtlkey** (dari SQL Accounting) sebagai stable key
  semasa upsert ke Supabase — elak duplicate rekod bila sync run
  berulang kali.
- Setiap sync run log (jayaan/gagal, bilangan rekod) untuk audit.

## 5. Kenapa schema `finance` berasingan

Supabase ISW sekarang guna schema `public` untuk jadual psikoterapi
sedia ada. Data kewangan dari SQL Accounting dicadang masuk schema
`finance` yang berasingan supaya:

- Tak bercampur dengan struktur jadual patient/coach sedia ada.
- Senang kawal akses (RLS berasingan untuk data kewangan sensitif).
- Senang rollback/buang kalau integrasi tak jadi, tanpa sentuh data
  psikoterapi.

## 6. Cara nak mula (bila requirement dah confirm)

1. **Test API dulu guna Postman** — SQL Account ada Postman Collection
   rasmi. Guna Access+Secret Key untuk test call asas (cth. get list
   invoice) SEBELUM tulis sync script. Ini sahkan API Service memang
   berfungsi & boleh dicapai dari luar rangkaian syarikat.
2. **Draf schema `finance`** (docs/migration sahaja dulu, bukan run
   production) berdasarkan data scope yang dah confirm.
3. **Bina sync script** kecil (satu jenis data dulu, cth. invoice
   sahaja) — authenticate → fetch → transform → upsert Supabase.
4. **Uji di testing environment** Supabase dulu sebelum apply ke
   prod.
5. **Automate** — sambung sync script sebagai scheduled job (cron)
   ikut frekuensi yang dah confirm.

## 7. Status semasa & sekatan

- **Belum ada** jawapan rasmi dari accountant/vendor SQL Account untuk
  Bahagian 3 (checklist) di atas.
- **Belum ada** confirmation dari manager pasal data scope & arah
  sync (Bahagian 3, item 8-10).
- **Tiada kod/migration** dibina lagi — semua di atas adalah pelan,
  bukan status siap.

**Langkah seterusnya paling logik:** hantar Bahagian 3 (checklist) ni
kepada accountant/IT syarikat yang uruskan SQL Accounting, dan
confirm dengan manager pasal data scope + arah sync sebelum draf
schema `finance`.
