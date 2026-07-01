# Panduan: Mesej Automatik WhatsApp 🟢

[← Kembali ke indeks panduan](../README.md)

---

## 1. Tujuan
Urus semua **mesej WhatsApp automatik** yang sistem hantar sendiri — peringatan acara, broadcast sesi berulang (cth Manzil Live), peringatan Catatan Harian, dan alert kepatuhan kepada coach. Dari satu skrin, staf boleh **edit teks (template)**, **set masa**, dan **hidup/matikan** setiap mesej. Ubah di sini terus berkesan — tiada perlu pasang semula (re-deploy) Edge Function.

> Penting: skrin ini **tidak** menghantar mesej satu-satu secara manual. Ia mengkonfigurasi mesej yang dicetus automatik oleh cron (setiap 15 minit). Hantaran sebenar melalui **GoHighLevel (GHL)**.

## 2. Siapa boleh buat
- **Edit (template, masa, on/off):** Staf dengan kebenaran modul **`auto_messages`** — biasanya **`super_admin`**.
- **Lihat sahaja:** `manager` (view, tak boleh ubah).
- (Lihat [Peranan & Akses](../../sistem/05-peranan-akses.md).)

## 3. Lokasi
- **Senarai mesej automatik:** Sidebar staf → kumpulan **KOMUNIKASI → Mesej Automatik** (`roles/staff/auto-mesej.html`)
- **Borang edit:** klik butang **Edit** pada mana-mana mesej dalam senarai → modal edit terbuka.

> Tiada butang "Tambah" — set mesej automatik telah disemai (seed) oleh migrasi. Staf hanya **edit** mesej sedia ada.

---

## 4. Langkah ringkas

1. Buka **Mesej Automatik**. Setiap kad papar: nama, jenis pencetus (label warna), status (● Aktif / ○ Tidak aktif), saluran, dan ringkasan masa.
2. Klik **Edit** pada mesej yang nak diubah.
3. Set **masa** ikut jenis mesej (lihat Seksyen 5):
   - Sebelum acara/sesi → pilih **berapa minit sebelum** (15/30/60 atau taip sendiri).
   - Broadcast berulang → pilih **hari**, **masa sesi**, **minit awal**, **pautan**, **saluran**, **sasaran**.
   - Harian → set **masa hantar setiap hari** (cth 20:00).
   - Serta-merta → tiada tetapan masa.
4. Edit **Teks Mesej**. Guna chip **Sisip** untuk masukkan placeholder (cth `{nama}`).
5. Semak **Pratonton** (gaya gelembung WhatsApp dengan nilai sampel).
6. Tanda / buang tanda **"Aktifkan mesej automatik ini"** untuk hidup/matikan.
7. Klik **💾 Simpan**.

> Pratonton guna nilai sampel (cth `Encik Ali`, `Kelas Mindfulness`) — bukan data sebenar. Ia hanya untuk lihat rupa mesej.

---

## 5. Field — wajib vs pilihan

### Header kad (senarai)
Bukan field input — hanya paparan ringkas setiap mesej:
| Item | Nota |
|------|------|
| Nama + label jenis | Label warna ikut `trigger_type` (Sebelum acara · Harian · Broadcast berulang · Serta-merta). |
| Status | **● Aktif** (hijau) atau **○ Tidak aktif** (kelabu). |
| Saluran + masa | Cth `📲 whatsapp · ⏱️ 30 minit sebelum`. |

### Modal edit — field bersama (semua jenis)
| Field | Wajib? | Nota |
|-------|--------|------|
| **Teks Mesej** `*` | ✅ **WAJIB** | Tak boleh kosong — sistem block. Sokong placeholder `{...}`. |
| Aktifkan mesej automatik ini | Pilihan | Checkbox = `is_active`. Tak tanda = mesej tak akan dihantar walaupun masa kena. |
| Sisip (chip placeholder) | — | Klik untuk masukkan placeholder sah pada kursor. Senarai chip ikut mesej. |

### Field masa — bergantung jenis pencetus
| Jenis (`trigger_type`) | Field masa | Wajib? | Nota |
|------------------------|-----------|--------|------|
| `before_event` / `before_session` | **Berapa lama sebelum** (minit) | ✅ ≥ 1 | Butang cepat 15/30/60 minit atau taip sendiri. |
| `recurring_broadcast` | **Hari hantar** `*` + **Masa sesi** `*` + **minit awal** `*` + **Saluran** `*` | ✅ | Lihat jadual broadcast bawah. |
| `daily_reminder` | **Hantar setiap hari pukul** (masa) | ✅ | Cth `20:00`. |
| `on_action` | (tiada) | — | "⚡ Dihantar serta-merta bila tindakan berlaku." |

### Field tambahan — Broadcast Berulang (`recurring_broadcast`) sahaja
| Field | Wajib? | Nota |
|-------|--------|------|
| **Hari hantar (setiap minggu)** `*` | ✅ sekurang-kurangnya 1 | Pilih Isn–Ahd (0=Ahad..6=Sabtu). |
| **Masa sesi bermula** `*` | ✅ | Masa sesi sebenar (cth 08:45). Mesej dihantar *minit awal* sebelum ini. |
| **Minit awal** `*` | ✅ ≥ 1 | Set di bahagian "berapa lama sebelum". |
| **Pautan (Google Meet)** | Pilihan | Mengisi placeholder `{pautan}`. |
| **Saluran hantar** `*` | ✅ sekurang-kurangnya 1 | 📲 WhatsApp · 🔔 Notifikasi app · 📢 Pengumuman. |
| **Sasaran** | Default semua | 👥 Semua pesakit **atau** 🎯 Pakej tertentu (pilih pakej). |

### Placeholder yang disokong
Diisi automatik oleh runner masa hantar:
| Placeholder | Maksud |
|-------------|--------|
| `{nama}` | Nama pesakit (atau coach untuk alert kepatuhan). |
| `{acara}` | Tajuk acara (peringatan acara). |
| `{masa}` | Masa acara/sesi. |
| `{lead}` | Berapa lama lagi (cth `30 minit`). |
| `{pautan}` | Link Google Meet / lokasi. |
| `{senarai}` | Senarai isu kepatuhan (alert coach sahaja). |

> Editor untuk medan **`rule`** (ambang alert kepatuhan — cth `min_score`, `min_days_missing`) **belum ada di UI**. Ubah ambang ini buat masa ini melalui SQL.

---

## 6. Apa jadi lepas Simpan
1. Rekod dikemaskini ke jadual **`psy_auto_messages`** (update — bukan insert; satu baris setiap mesej, kunci `key`).
2. `updated_at` + `updated_by` direkod.
3. Banner **"Mesej automatik dikemaskini ✅"** muncul; senarai dimuat semula.
4. **Berkesan serta-merta** — runner (Edge Function `event-reminders`) baca konfig terkini pada cetusan cron seterusnya (setiap 15 minit). Tiada re-deploy perlu.
5. Jika **Aktif** + masa kena (dalam window ±10 minit) → runner berkenaan hantar mesej via GHL.

### Runner mana aktif? (status semasa)
Cron `event-reminders` jalankan **4 runner** setiap 15 minit. Setiap satu dipacu satu baris `psy_auto_messages` dan di-gate oleh `is_active`:

| # | Runner | Mesej (`key`) | Jenis | Status |
|---|--------|---------------|-------|--------|
| 1 | `runEventReminders` | `event_reminder` — Peringatan Acara & Kelas | `before_event` | 🟢 **LIVE** (testing). Hantar WA kpd pendaftar sebelum acara. |
| 2 | `runBroadcasts` | `manzil_live` — Live Bacaan Manzil | `recurring_broadcast` | ⚪ **Draf (off)**. Lengkapkan link + aktifkan. WA+loceng+Pengumuman. |
| 3 | `runCatatanHarianReminder` | `catatan_harian` — Peringatan Catatan Harian | `daily_reminder` | ⚪ **Draf (off)**. WA kpd pesakit aktif yang belum isi Catatan Harian. |
| 4 | `runKepatuhanAlerts` | `kepatuhan_alert` — Alert Coach Kepatuhan | `daily_reminder` | ⚪ **Draf (off)**. Alert gabungan kpd COACH (loceng + `risk.html`). |
| — | (tiada runner) | `birthday` — Ucapan Hari Jadi | `daily_reminder` | ⚪ **Draf (off)** — pencetus belum disambung. |

> **Deploy production masih pending.** Runner 3 & 4 sengaja `is_active=false` — staf hidupkan di UI bila GHL sedia & sudah diuji. Aliran **dua-hala reschedule** (tanya boleh hadir → auto-reschedule) = **Fasa 2**, belum dibina.

> ⚠️ Broadcast (#2) hantar ke **semua pesakit** sasaran = volume WA besar. Uji guna pakej ujian / diri sendiri dahulu sebelum hidupkan untuk semua.

---

## 7. Masalah biasa
| Mesej / gejala | Sebab & penyelesaian |
|----------------|----------------------|
| "Teks mesej tak boleh kosong." | Isi field **Teks Mesej** dulu. |
| "Pilih sekurang-kurangnya satu hari." | Broadcast berulang: pilih ≥ 1 hari hantar. |
| "Sila set masa sesi bermula." | Broadcast berulang: isi masa sesi (cth 08:45). |
| "Sila set berapa minit sebelum." | Set minit awal (≥ 1). |
| "Pilih sekurang-kurangnya satu saluran." | Broadcast berulang: tanda ≥ 1 (WhatsApp / Notifikasi / Pengumuman). |
| "Sila set masa hantar harian." | Jenis harian: isi masa (cth 20:00). |
| Mesej Aktif tapi pesakit tak terima | Semak: (a) masih dalam window ±10 min vs masa set; (b) GHL secret/cron berfungsi; (c) pesakit ada **no. telefon** sah; (d) untuk broadcast — sasaran pakej betul; (e) untuk Catatan Harian — pesakit belum isi log hari itu. |
| Broadcast hantar 2 kali / tak hantar lagi hari ini | Normal — dedup harian guna `last_broadcast_at` (1×/hari/mesej). |
| Nak ubah ambang alert (min skor, hari miss) | Belum ada di UI — ubah medan `rule` (jsonb) via SQL. |
| Modul tak nampak di sidebar | Tiada kebenaran `auto_messages`. Hanya `super_admin` (edit) / `manager` (view). |

---

## 8. Rujukan teknikal
- Page: [`roles/staff/auto-mesej.html`](../../../roles/staff/auto-mesej.html) · `saveMsg()` ~ baris 294, `load()` ~ baris 336
- Runner: [`supabase/functions/event-reminders/index.ts`](../../../supabase/functions/event-reminders/index.ts) — 4 runner (`runEventReminders`, `runBroadcasts`, `runCatatanHarianReminder`, `runKepatuhanAlerts`)
- Jadual: `psy_auto_messages` (lihat [02-pangkalan-data.md](../../sistem/02-pangkalan-data.md))
- Migrasi:
  - [`supabase/migrations/20260623_auto_messages.sql`](../../../supabase/migrations/20260623_auto_messages.sql) — rangka + seed `event_reminder`/`catatan_harian`/`birthday`
  - [`supabase/migrations/20260624_auto_messages_broadcast.sql`](../../../supabase/migrations/20260624_auto_messages_broadcast.sql) — `recurring_broadcast` + seed `manzil_live`
  - [`supabase/migrations/20260625_catatan_harian_reminder.sql`](../../../supabase/migrations/20260625_catatan_harian_reminder.sql) — sambung pencetus Catatan Harian
  - [`supabase/migrations/20260626_kepatuhan_alerts.sql`](../../../supabase/migrations/20260626_kepatuhan_alerts.sql) — lajur `rule` + seed `kepatuhan_alert`
- Automasi & status deploy: [04-automasi-edge.md](../../sistem/04-automasi-edge.md)
