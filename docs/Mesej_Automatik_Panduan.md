# Panduan Modul "Mesej Automatik" (Automation) — ISW

> Modul hantar mesej automatik/broadcast kepada pesakit melalui WhatsApp, In-App & Email.
> Semua data adalah **sebenar** — tiada metrik palsu. Yang tak dijejak dinyatakan jujur.
> Kemas kini: 10 Julai 2026.

---

## 1. Gambaran Keseluruhan (Architecture ringkas)

```
Staff (UI)  ─cipta/edit─►  psy_automations ──┐
                                             │ (cron 15 min)
Enjin: supabase/functions/event-reminders ◄──┘
   │  1. Baca automasi aktif (trigger 'schedule')
   │  2. Tapis penerima  → applyConds()  (guna psy_patients / psy_audiences)
   │  3. Isi pembolehubah → buildPatientVars()  (psy_patients + pakej + coach + plan + klinik)
   │  4. Hantar via GHL   → WhatsApp / In-App / Email
   └► Rekod setiap hantaran → psy_notification_logs (sent / failed / pending)
                                             │
Staff (UI)  ◄──papar Dashboard/Log/Detail────┘
```

**Jadual data utama:**
| Jadual | Peranan |
|---|---|
| `psy_automations` | Definisi automasi: pencetus, syarat, tindakan, mesej, jadual, status |
| `psy_notification_logs` | Rekod setiap hantaran: status (sent/failed/pending), saluran, pesakit |
| `psy_audiences` | Set kriteria sasaran bernama (guna semula) |
| `psy_auto_messages` | Template mesej + mesej sistem (kategori, bahasa, tag) |
| `psy_patients` / `psy_packages` / `psy_profiles` / `psy_treatment_plans` | Sumber data pembolehubah |

**Enjin:** `supabase/functions/event-reminders/index.ts` — dicetus cron setiap 15 minit. Fungsi teras: `runScheduledAutomations()` → `applyConds()` → `buildPatientVars()` → `logAuto()`.

---

## 2. Peta Halaman (Navbar: Komunikasi → Mesej Automatik)

| # | Halaman | Fail | Tujuan |
|---|---|---|---|
| 1 | **Dashboard** | `automation-dashboard.html` | Gambaran harian: KPI, trend, queue, status automasi |
| 2 | **Senarai Automasi** | `automations.html` | Semua automasi (termasuk broadcast) — jadual, filter, on/off, padam |
| 3 | **Cipta / Edit Automasi** | `automation-builder.html` | Borang 5-langkah bina automasi |
| 4 | **Template Mesej** | `auto-mesej.html` | Urus mesej sistem sedia ada (broadcast, peringatan) |
| 5 | **Variables Library** | `variables-library.html` | Senarai pembolehubah + pratonton data sebenar |
| 7 | **Audience** | `automation-audience.html` | Cipta set sasaran + anggaran hidup |
| 8 | **Queue / Scheduled** | `automation-queue.html` | Automasi berjadual akan datang |
| 9 | **Log Penghantaran** | `automation-logs.html` | Rekod hantaran + Export CSV |
| 10 | **Butiran Automasi** | `automation-detail.html` | Prestasi + konfigurasi satu automasi |
| 11 | **Test Automation** | `test-automation.html` | Hantar ujian sebenar sebelum aktif |

> *Analytics DIBUANG* — bertindih dengan Dashboard + banyak metrik (Dibaca/Respon) tak dijejak.

---

## 3. Cara Guna Setiap Halaman

### 1) Dashboard
- **Tujuan:** pantau kesihatan automasi harian.
- **Ada apa:** 5 KPI (dengan delta vs tempoh lepas), carta trend, donut saluran, queue hari ini, status automasi (aktif/draf/dijeda), quick actions.
- **Pemilih julat tarikh** di atas (7/14/30 hari/bulan/custom).
- **Data:** `psy_notification_logs` + `psy_automations`.

### 2) Senarai Automasi
- **Tujuan:** urus semua automasi.
- **Tindakan:** 👁 Lihat (→ Detail) · ✎ Edit (→ Builder) · ⏸/▶ jeda/aktif · 🗑 padam.
- **Filter:** carian, kategori, status, saluran.
- Broadcast muncul di sini sebagai kategori **"Broadcast"** (pencetus jadual).

### 3) Cipta / Edit Automasi (5 langkah)
1. **Pencetus** — kategori + event (cth Broadcast Berjadual, Rujukan Dibuat).
2. **Syarat** — sasaran pesakit; boleh **guna Audience Tersimpan** atau tetap sendiri (status/pakej/jantina/umur/negeri).
3. **Tindakan** — saluran hantar (WhatsApp / In-App / Email).
4. **Kandungan Mesej** — teks + pembolehubah (guna template atau tulis sendiri).
5. **Semakan** — sahkan & simpan.
- **Nota:** kategori/event ialah *registry dalam kod* (bukan boleh-edit UI) supaya tiada pilihan "mati".

### 4) Template Mesej (galeri)
- **Tujuan:** simpan ayat mesej boleh guna semula.
- **"+ Tambah Template"** & **Edit** (untuk template) → Template Builder.
- Mesej *sistem* (cth Saranan Rujukan) diedit melalui modal.

### 5) Template Builder (editor penuh)
- **Kiri:** Nama · Saluran · Kategori · Bahasa · Tag · Penerangan · Status · metadata (Dicipta Oleh/Tarikh).
- **Tengah (bertab):** *Kandungan Mesej* (toolbar B/I/S/mono/senarai + **Insert Variable** + Pembolehubah Digunakan) · *Tetapan Lanjutan* (Butang/Lampiran/Fallback = "Akan datang").
- **Kanan:** Pratonton WhatsApp + Senarai Pembolehubah berkategori + Tips.
- **Hantar Ujian** — hantar mesej ujian sebenar via GHL.

### 6) Variables Library
- **Tujuan:** rujukan semua pembolehubah yang **betul-betul diisi** sistem.
- Cari, tab kategori, salin satu/semua, **Preview** guna pesakit sebenar.
- Kategori: **Pesakit · Pakej & Rawatan · Coach & Klinik · Sistem · Temujanji**.
- Pembayaran ditanda *"perlu pencetus khusus"* (belum disenarai).

### 7) Audience (Cipta Audience)
- **Tujuan:** simpan set sasaran bernama untuk guna semula.
- **Kriteria:** Status · Pakej · Jantina · Umur · Negeri · Tarikh Pendaftaran.
- **Anggaran hidup** (donut + pecahan jantina/umur/negeri/pakej) update serta-merta.
- Simpan → `psy_audiences` → boleh pilih dalam Builder (langkah Syarat).

### 8) Queue / Scheduled
- **Tujuan:** lihat automasi berjadual yang **akan** dihantar.
- Jadual: masa seterusnya, automasi, kategori, jadual, saluran, penerima.

### 9) Log Penghantaran
- **Tujuan:** rekod penuh setiap hantaran.
- Filter (status/saluran/automasi) + **Export CSV**.

### 10) Butiran Automasi
- **Hero:** ikon saluran + nama + status + meta (Saluran/Kategori/Audiens/Dicipta Oleh/ID) + panel status.
- **Ringkasan Prestasi:** Audiens · Diproses · Berjaya · Gagal · Kadar (30 hari).
- **Status Penghantaran** (bar) · **donut Saluran** · Pratonton · Pencetus · Sasaran · Aktiviti Terkini · **Export Log**.

### 11) Test Automation
- 4 langkah: pilih automasi/template → pilih pesakit (carian) → pilih saluran → **Hantar Ujian Sekarang**.
- Hantar **sebenar**: WhatsApp (GHL) + In-App (`psy_notifications`); mesej diisi data pesakit betul.
- Keputusan: Status + Masa Dihantar sebenar; Disalurkan/Dibaca/Respon = *tidak dijejak*.

---

## 4. Sistem Pembolehubah (Variables)

- **Format:** `{{kunci}}` (dua kurungan). Contoh: `{{nama}}`, `{{pakej}}`, `{{minggu}}`.
- **Kunci Bahasa Melayu** (konsisten seluruh sistem).
- Enjin isi guna `buildPatientVars()` — sumber data sebenar:

| Kategori | Contoh kunci | Sumber |
|---|---|---|
| Pesakit | nama, mrn, ic, telefon, emel, jantina, negeri, umur | `psy_patients` |
| Pakej & Rawatan | pakej, kod_pakej, minggu, jumlah_minggu, tarikh_mula, tarikh_tamat | `psy_patients` + `psy_packages` + `psy_treatment_plans` |
| Coach & Klinik | coach, nama_klinik, telefon_klinik, alamat_klinik | `coach_id`→`psy_profiles` + pemalar klinik |
| Sistem | tarikh, masa, hari, tahun, bulan | tarikh sistem (GMT+8) |
| Temujanji | (sesi rawatan terdekat "Ditempah") | sumber sesi pesakit |

> Pembayaran belum disenarai — perlu pencetus event pembayaran.

---

## 5. Kejujuran Data (Had Semasa)

 Diguna secara konsisten seluruh modul — **tidak** dipapar sebagai palsu:
- **Dibaca / Respon** — GHL hantar teks biasa; tiada read-receipt/webhook balasan. **Tidak dijejak.**
- **SMS** — dibuang (guna WhatsApp).
- **Retry automatik** — belum ada dalam enjin.
- **Butang WhatsApp / Lampiran / Fallback** — "Akan datang" (GHL teks biasa).
- Metrik `0` bermakna **belum ada hantaran**, bukan ralat.

---

## 6. Senarai Semak Deploy PROD (xmvqvq — MCP tiada akses, run manual)

1. Run SQL di Supabase (ikut turutan):
   - `step84` — RLS staff kemas kini profil pesakit **(WAJIB)**
   - `step85` — seed template saranan **(optional; ada fallback)**
   - `step86` — `psy_automations` + `psy_notification_logs` **(WAJIB)**
   - `step87` — `psy_audiences` **(WAJIB)**
   - `step88` — kolum `status` automasi **(WAJIB)**
   - `step89` — `category` + `language` template **(WAJIB)**
   - `step90` — `tags` + `created_by` template **(WAJIB)**
2. **Redeploy** Edge Function `event-reminders` (enjin + pembolehubah) — **WAJIB (testing & prod)**.
3. Set secrets: `GHL_ISW_TOKEN`, `GHL_ISW_LOCATION_ID`, `CRON_SECRET`, `GHL_EMAIL_FROM`.
4. Set **cron 15-minit** panggil fungsi (header `x-cron-secret`).
5. **Cutover broadcast lama** (elak hantar 2×): pindah `recurring_broadcast` dari `psy_auto_messages` → `psy_automations`, matikan `runBroadcasts`.

---

## 7. Aliran Hujung-ke-Hujung (contoh)

1. Staff cipta automasi *"Peringatan Check-in Harian"* (Builder) → simpan ke `psy_automations` (status: aktif).
2. Cron cetus enjin tiap 15 min → enjin jumpa automasi ini pada masa jadual.
3. `applyConds()` tapis pesakit layak (cth: status aktif, pakej OBD).
4. `buildPatientVars()` isi `{{nama}}`, `{{minggu}}`, dll untuk setiap pesakit.
5. Hantar via GHL (WhatsApp) / In-App / Email.
6. Setiap hantaran direkod ke `psy_notification_logs` (sent/failed).
7. Staff pantau di **Dashboard / Log / Butiran Automasi**.
```
```
```

Lihat juga: `docs/Mesej_Automatik_Prompt_Architecture.md` untuk prompt jana rajah flow di GPT/Claude.
