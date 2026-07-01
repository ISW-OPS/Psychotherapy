# 01 — Seni Bina Teknikal

[← Kembali ke indeks](README.md)

Dokumen ini untuk pembangun (developer). Menerangkan susunan kod, pustaka dikongsi, konfigurasi persekitaran, dan cara deploy.

---

## 1. Falsafah seni bina

- **Tiada framework, tiada build step.** Semua halaman ialah HTML statik. Tailwind dimuat dari CDN, JavaScript ditulis vanilla. Tiada `npm build`, tiada bundler — fail dihidang terus.
- **Supabase sebagai backend penuh.** Database, Auth, Storage, dan logik server (Edge Functions) semuanya di Supabase. Frontend bercakap terus dengan Supabase melalui `supabase-js` (klien dimuat dari CDN).
- **Keselamatan di lapisan DB.** Kawalan akses sebenar dikuatkuasakan oleh **Row-Level Security (RLS)** di PostgreSQL, bukan hanya di UI. `authGuard.js` cuma kawalan UI/navigasi; RLS yang lindungi data.
- **Kod dikongsi di `shared/`.** Satu edit pada `navbar.js` atau `i18n.js` aktif di semua halaman.

---

## 2. Susunan satu halaman (page anatomy)

Setiap halaman role biasanya muat skrip dalam susunan ini:

```html
<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>
<script src="/config/supabase.js"></script>     <!-- klien db + helper -->
<script src="/shared/authGuard.js"></script>     <!-- semak sesi + peranan -->
<script src="/shared/navbar.js"></script>         <!-- nav + auto-muat i18n + pwa -->
<!-- pustaka lain ikut keperluan: inventoryDeduct, letterTemplates, dll -->
```

`navbar.js` ialah loader pusat — ia auto-muat `i18n.js` (dwibahasa) dan `pwa.js` pada setiap halaman role, jadi tak perlu tambah secara manual.

---

## 3. `config/supabase.js` — teras sambungan

Fail ini wujudkan klien Supabase global dan beberapa helper. Titik penting:

### Pemilihan persekitaran (env)
```js
production : https://xmvqvqrifhwoehdfsoau.supabase.co
testing    : https://ipmemyizigwgivccytcu.supabase.co
```
- `localhost`/`127.0.0.1` → guna **testing** secara default.
- Tapak yang di-deploy → guna **production**.
- Boleh override melalui `localStorage('isw_env')`.
- **Badge env** (merah=PROD, jingga=TESTING) dipaparkan di penjuru bawah-kanan **hanya untuk staf** — klik untuk tukar env (developer only).

### Objek & helper global
| Nama | Guna |
|------|------|
| `window.db` | Klien Supabase (guna `db.from('...')...`) |
| `window.ISW_ENV` | `'production'` / `'testing'` |
| `dbQuery(table, opts)` | SELECT ringkas (select/eq/order/limit/single) |
| `dbInsert(table, row)` | INSERT + pulang baris |
| `dbUpdate(table, id, updates)` | UPDATE (guna `maybeSingle` — elak ralat RLS selepas update) |
| `dbDelete(table, id)` | DELETE ikut id |
| `getCurrentUser()` | Pulang `auth.user` digabung dengan baris `psy_profiles` |
| `auditLog(action, target, meta)` | Tulis ke `psy_audit_log` |

> Nota RLS: `dbUpdate` sengaja guna `.maybeSingle()` (bukan `.single()`) sebab RLS kadang sekat SELECT-selepas-UPDATE walaupun UPDATE berjaya; `single()` akan throw "Cannot coerce" pada 0 baris padahal data tersimpan.

---

## 4. Pustaka `shared/*.js`

| Fail | Fungsi |
|------|--------|
| `navbar.js` | Jana sidebar/topbar dinamik ikut peranan; auto-muat `i18n.js` + `pwa.js`; butang toggle EN/BM; bottom tab bar (pesakit mobile) |
| `authGuard.js` | Semak sesi login + peranan; petakan halaman → modul kebenaran (`PAGE_MODULE`); fungsi `can(module, action)` |
| `i18n.js` | Enjin dwibahasa BM⇄EN — tukar text node + atribut; cache asal untuk restore; MutationObserver untuk kandungan dinamik |
| `i18n-dict.js` | Glosari auto-jana (`window.ISW_I18N_EXTRA`) — 5,339 entri BM→EN (jangan edit tangan) |
| `logout.js` | Logout + bersih sesi |
| `theme.js` | Penukar tema |
| `utils.js` | Fungsi utiliti am |
| `adherence.js` | Pengiraan skor kepatuhan |
| `inventoryDeduct.js` | Auto-tolak stok bila sesi tanda hadir (`deductSessionSupplies()`) |
| `stockSync.js` | Auto-sync Inventori ↔ Produk ikut nama (case-insensitive) |
| `defaultAgreement.js` | 29 klausa kontrak default (fallback bila pakej tiada override) |
| `defaultDailySchedule.js` | Jadual harian sampel default ikut pakej (OB schedule) |
| `letterTemplates.js` | Definisi 7 template surat rasmi + jana PDF |
| `referral.js` | Logik program rujukan |
| `pwa.js` | Daftar service worker / PWA (Add-to-Home, offline) |

---

## 5. Auth & Storage

- **Auth**: Supabase Auth (email + password). Halaman: `auth/login.html`, `auth/reset.html`, `auth/set-password.html` (selepas reset/invite). Logik di `auth/auth.js`.
- **Jemput staf**: Edge Function `invite-staff` cipta akaun staf + hantar magic link set-password.
- **Storage buckets**: agreement PDF, rujukan KOB, gambar isu produk, laporan perubatan, fail surat — semua di Supabase Storage dengan polisi akses.

---

## 6. Deploy

| Fail | Guna |
|------|------|
| `vercel.json` | Konfigurasi deploy Vercel (static) |
| `railway.json` | Konfigurasi deploy Railway |
| `server.js`, `serve.json` | Pelayan statik Node.js/Express (local/alternatif) |
| `offline.html` | Halaman fallback PWA bila offline |

**Edge Functions** dideploy berasingan ke Supabase (lihat [04 — Automasi](04-automasi-edge.md)). Production (`xmvqvq`) **tiada akses MCP** — deploy/SQL dibuat manual oleh user melalui Supabase Dashboard.

---

## 7. Dwibahasa (i18n) — ringkas

- Sumber HTML kekal **Bahasa Melayu**; enjin tukar ke EN bila `lang=en`.
- Glosari penuh (`i18n-dict.js`) ada **5,339** entri BM→English (auto-jana via workflow, regenerasi 24 Jun 2026).
- Seed terkurasi dalam `i18n.js` **menang** atas glosari auto (hanya isi kunci yang tiada).
- **Had diketahui**: string dinamik dengan interpolasi `${...}` tak boleh diterjemah (kekal BM); 2 halaman tiada navbar.js jadi tiada enjin: `roles/patient/kob-agreement.html`, `roles/patient/kepatuhan-flow-preview.html`.
- Untuk terjemah string baru: tambah ke seed `EN` dalam `shared/i18n.js`.

Detail penuh: lihat memori projek `project_i18n_bilingual`.

---

Seterusnya: [02 — Pangkalan Data →](02-pangkalan-data.md)
