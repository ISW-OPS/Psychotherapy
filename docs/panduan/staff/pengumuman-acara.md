# Panduan: Pengumuman & Acara / Kelas 🟢

[← Kembali ke indeks panduan](../README.md)

---

## 1. Tujuan
Maklumkan pesakit (dan staf) tentang berita, promosi, notis sistem, **atau** acara/kelas/webinar — termasuk reminder WhatsApp automatik sebelum acara bermula.

Dua jenis rekod dibuat dari **satu borang yang sama** (`pengumuman-baru.html`), bergantung pada **Jenis Pengumuman** yang dipilih:

| Jenis | Disimpan ke jadual | Pesakit nampak di |
|-------|--------------------|-------------------|
| **Pengumuman biasa** (Makluman, Survey, Kemaskini Sistem…) | `psy_announcements` | `roles/patient/announcements.html` |
| **Acara / Kelas** (Event F2F, Webinar, Manzil…) | `psy_events` | `roles/patient/events.html` → `event-detail.html` |

> Bezanya: jenis **event** ada Tarikh + Masa + Lokasi/Online + Kapasiti + reminder automatik. Pengumuman biasa hanya tajuk + kandungan + butang tindakan (CTA) pilihan.

## 2. Siapa boleh buat
Staf dengan kebenaran modul **`announcements`** (cipta/edit pengumuman) dan **`events_admin`** (urus acara) — biasanya `super_admin`, `admin`, `manager`. (Lihat [Peranan & Akses](../../sistem/05-peranan-akses.md).)

> **`super_admin` sahaja** boleh **Urus Jenis Pengumuman** dan **Urus Kategori** (tambah/edit/padam) melalui pilihan **⚙️** dalam dropdown.

## 3. Lokasi
- **Senarai pengumuman:** Sidebar staf → **OPERASI → Pengumuman** (`roles/staff/announcements.html`)
- **Senarai acara/kelas:** Sidebar staf → **Acara & Kelas** (`roles/staff/events.html`)
- **Borang cipta (pengumuman & acara):** `roles/staff/pengumuman-baru.html`
  - Dari `announcements.html`: butang **"+ Tambah Pengumuman"**
  - Dari `events.html`: butang **"+ Cipta di Pengumuman"**
- **Edit pengumuman:** `roles/staff/pengumuman-edit.html` (klik pengumuman → Edit)
- **Edit acara cepat:** modal **✏️ Edit Acara** terus dalam `events.html` (klik kad acara), atau halaman penuh `acara-detail.html`

---

## 4. Langkah ringkas

### A) Cipta Pengumuman biasa
1. Buka **Pengumuman** → **+ Tambah Pengumuman**.
2. **Jenis Pengumuman** → pilih jenis biasa (cth `Makluman`, `Survey / Tindakan`, `Kemaskini Sistem`).
3. **Sasaran Pengguna** → pilih **Semua Pesakit** / **Pakej Tertentu** / **Staff**.
4. Isi **Tajuk**, **Kategori**, **Ringkasan Pendek**. (Pilihan: Banner, Tarikh Tamat Papar, Butang Tindakan/CTA.)
5. Klik **🚀 Publish Pengumuman** (atau **📄 Simpan Draft** untuk sembunyi dulu).

### B) Cipta Acara / Kelas
1. Buka **Pengumuman** → **+ Tambah Pengumuman** (atau dari `events.html` → **+ Cipta di Pengumuman**).
2. **Jenis Pengumuman** → pilih jenis **event** (cth `Event Fizikal (F2F)`, `Webinar / Online`, `Bacaan Manzil`). Kad **Maklumat Event** akan muncul.
3. **Sasaran Pengguna** + isi **Tajuk**, **Kategori**, **Ringkasan**.
4. Isi **Maklumat Event**: **Tarikh**, **Masa Mula** (wajib), Masa Tamat, Lokasi/Pautan, Pengendali, Kapasiti.
5. Klik **🚀 Publish** → diarah ke `events.html`.

> **Edit acara cepat** (tukar masa, mod, harga, pautan rakaman, batalkan): buka `events.html`, klik kad → modal **Edit Acara**. Tukar status ke **Cancelled** akan auto-maklum pesakit berdaftar (loceng dalam app).

---

## 5. Field — wajib vs pilihan

### Bersama (semua jenis) — `pengumuman-baru.html`
| Field | Wajib? | Nota |
|-------|--------|------|
| **Jenis Pengumuman** `*` | ✅ Pilih | Menentukan sama ada rekod jadi **pengumuman** atau **event**. Default `Event Fizikal (F2F)`. |
| **Sasaran Pengguna** `*` | ✅ **WAJIB** | Pilih ≥1: 👥 Semua Pesakit · 🎯 Pakej Tertentu (mesti pilih ≥1 pakej) · 🧑‍⚕️ Staff. "Semua Pesakit" & "Pakej Tertentu" saling eksklusif. |
| **Tajuk** `*` | ✅ **WAJIB** | Maks 150 aksara. |
| **Kategori** `*` | Disyorkan | Dari `psy_announcement_categories`. Kalau kosong, sistem guna nama jenis sebagai kategori. |
| **Ringkasan Pendek** `*` | ✅ **WAJIB** | Maks 200 aksara. Ini jadi `body` (pengumuman) / `description` (event). |
| Banner / Gambar | Pilihan | JPG/PNG, **maks 5MB**. Auto-crop nisbah **2:1** (1200×600px). |

### Khusus PENGUMUMAN biasa
| Field | Wajib? | Nota |
|-------|--------|------|
| Tarikh Tamat Papar | Pilihan | `datetime-local`. Auto-sembunyi dari pesakit selepas tarikh. Kosong = kekal. |
| Butang Tindakan (CTA) — Label + URL | Pilihan (berpasangan) | Kalau isi satu, **wajib** isi kedua-dua. Untuk jenis **Survey/Tindakan**, tukar jadi **Pautan Borang** (cth Google Form). |

### Khusus EVENT (kad "Maklumat Event")
| Field | Wajib? | Nota |
|-------|--------|------|
| **📅 Tarikh Event** `*` | ✅ **WAJIB** | |
| **🕒 Masa Mula** `*` | ✅ **WAJIB** | |
| 🕒 Masa Tamat | Pilihan | Kosong = tiada masa tamat. |
| **📍 Nama Lokasi** `*` | ✅ **WAJIB untuk F2F** | Untuk event **online**, lokasi jadi opsyenal. |
| 📍 Alamat Lokasi | Pilihan | F2F sahaja. |
| 🗺 Google Maps URL **/** 📹 Pautan Sertai | Pilihan | F2F = Maps URL (`maps_url`). Online = pautan Meet/Zoom (`meet_link`). Bertukar ikut mod jenis. |
| 👤 Pengendali Program (peranan + nama) | Pilihan | Peranan: Penceramah / Coach / Moderator. |
| 👥 Kapasiti Peserta | Pilihan | Kosong = tiada had. |

> **Field tambahan dalam modal `events.html`** (tak ada di borang cipta): **Tag** (label kad), **Mod** (online/F2F), **Harga (RM, 0 = percuma)**, **Pautan rakaman** (selepas acara), dan **Status** (Published/Draft/Completed/Cancelled).

---

## 6. Apa jadi lepas Simpan

### Pengumuman biasa
1. Insert ke **`psy_announcements`** (`title`, `body`, `category`, `tag`, `image_url`, `audience`, `package_ids`, `cta_label`, `cta_url`, `expires_at`).
2. `is_active = true` kalau **Publish**, `false` kalau **Draft**.
3. Diarah ke `announcements.html`. Pesakit yang padan **sasaran** nampak di `roles/patient/announcements.html` (kalau aktif & belum tamat).

### Event
1. Insert ke **`psy_events`** (`title`, `description`, `type`, `mode`, `start_at`, `end_at`, `location`, `address`, `maps_url`/`meet_link`, `capacity`, `host`, `host_role`, `cover_image`, `audience`, `package_ids`).
2. `status = 'published'` (papar) atau `'draft'` (sembunyi).
3. Diarah ke `events.html`. Pesakit nampak di `roles/patient/events.html` → boleh **daftar** (rekod ke `psy_event_registrations`).
4. **Reminder automatik** dijadualkan (lihat bawah). Pendaftar boleh ditanda **Hadir** & dieksport CSV dari modal **Pendaftar** di `events.html`.

### Reminder acara automatik (`supabase/functions/event-reminders/`)
- Cron (**tiap 15 minit**) panggil Edge Function `event-reminders`.
- Untuk acara **`status='published'`** yang akan mula dalam tetingkap reminder (default **30 minit** sebelum, ikut tetapan `psy_auto_messages` key `event_reminder`), hantar **WhatsApp** (via GoHighLevel) kepada setiap pendaftar yang ada no. telefon sah.
- **Idempotent**: setiap pendaftaran diperingat **sekali sahaja** (`psy_event_registrations.reminder_sent_at`).
- Tetapan template + masa reminder boleh diubah di UI **Mesej Automatik** (`auto-mesej.html`). Fungsi yang sama juga jalankan broadcast berulang (cth Manzil), peringatan Catatan Harian & alert kepatuhan coach.

---

## 7. Masalah biasa
| Mesej / gejala | Sebab & penyelesaian |
|----------------|----------------------|
| "Tajuk Pengumuman wajib diisi" | Isi field **Tajuk**. |
| "Ringkasan Pendek wajib diisi" | Isi **Ringkasan Pendek**. |
| "Pilih sekurang-kurangnya satu sasaran pengguna" | Tanda ≥1 dalam **Sasaran Pengguna**. |
| "Sila pilih sekurang-kurangnya satu pakej…" | Anda pilih **Pakej Tertentu** tapi tiada pakej ditanda. Pilih pakej atau tukar ke Semua Pesakit. |
| "Tarikh & Masa Mula event wajib diisi" | Isi **Tarikh** + **Masa Mula** untuk event. |
| "Nama Lokasi wajib diisi untuk event fizikal" | Event F2F mesti ada **Nama Lokasi** (atau tukar jenis ke Online). |
| "Sila isi URL/label untuk butang tindakan" | CTA berpasangan — isi **kedua-dua** Label & URL, atau kosongkan kedua-duanya. |
| "Gambar melebihi 5MB" | Kecilkan gambar sebelum upload (banner maks 5MB). |
| Pilihan **⚙️ Urus jenis / kategori** tak nampak | Hanya `super_admin` nampak. |
| Pesakit tak terima reminder WhatsApp | Pesakit tiada no. telefon sah (di-skip), acara bukan `published`, atau key `event_reminder` **off** di `auto-mesej.html`. Saluran hantar = `type:'SMS'` (di-route ke WhatsApp) — bukan WhatsApp rasmi. |
| Acara dibatalkan tapi pendaftar tak dimaklum | Auto-maklum hanya berlaku bila status ditukar **ke** `Cancelled` (loceng dalam app, bukan WhatsApp). |

---

## 8. Rujukan teknikal
- Borang cipta: [`roles/staff/pengumuman-baru.html`](../../../roles/staff/pengumuman-baru.html) · `submitForm()` ~ baris 446
- Edit pengumuman: [`roles/staff/pengumuman-edit.html`](../../../roles/staff/pengumuman-edit.html)
- Senarai/edit acara: [`roles/staff/events.html`](../../../roles/staff/events.html) · `saveEvent()` ~ baris 312 · [`acara-detail.html`](../../../roles/staff/acara-detail.html)
- Senarai pengumuman: [`roles/staff/announcements.html`](../../../roles/staff/announcements.html) · [`announcement-detail.html`](../../../roles/staff/announcement-detail.html)
- Paparan pesakit: [`roles/patient/announcements.html`](../../../roles/patient/announcements.html) · [`events.html`](../../../roles/patient/events.html) · [`event-detail.html`](../../../roles/patient/event-detail.html)
- Reminder automatik: [`supabase/functions/event-reminders/index.ts`](../../../supabase/functions/event-reminders/index.ts) · [README](../../../supabase/functions/event-reminders/README.md)
- Jadual: `psy_announcements`, `psy_events`, `psy_event_registrations`, `psy_announcement_types`, `psy_announcement_categories`, `psy_auto_messages` (lihat [02-pangkalan-data.md](../../sistem/02-pangkalan-data.md))
</content>
</invoke>
