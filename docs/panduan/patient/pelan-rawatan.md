# Panduan: Pelan Rawatan & Jadual Harian 🔵

[← Kembali ke indeks panduan](../README.md)

---

## 1. Tujuan
Lihat pelan rawatan mingguan anda (sesi coaching, bimbingan, bekalan, mode F2F/online + link Gmeet), tetapkan & uruskan jadual sesi mingguan, jejak aktiviti harian (Jadual Harian), dan rekod bacaan kesihatan (vitals). Kebanyakan halaman ini **untuk dilihat sahaja** — coach yang merekod nota, vitals sesi, dan kepatuhan. Yang **anda** boleh ubah ialah jadual sesi, Jadual Harian, checklist matlamat, feedback, dan bacaan sendiri.

## 2. Siapa boleh buat
**Pesakit** yang sudah ada **pakej rawatan aktif**. Treatment Plan muncul automatik selepas anda beli pakej dan buat bayaran (lihat [pakej](pakej.html) & [payment](payment.html)). Tanpa pakej aktif, halaman tunjuk skrin "Belum Ada Pelan Rawatan".

## 3. Lokasi
- **Pelan Rawatan (utama):** Menu bawah → **Plan** (`roles/patient/plan.html`)
- **Butiran Mingguan:** dari kad minggu → **📋 Lihat butiran & bekalan minggu ini** (`roles/patient/plan-week.html?plan_id=…&week=N`)
- **Jadual Harian:** menu pesakit → **Jadual Harian** (`roles/patient/routine.html`)
- **Bacaan Saya (vitals):** menu pesakit → **Bacaan Saya** (`roles/patient/vitals.html`)

---

## 4. Langkah ringkas

1. Buka **Plan**. Kali pertama, sistem tunjuk **wizard setup jadual** — pilih pasangan hari & jam.
2. Sistem **auto-jadual** semua sesi untuk seluruh tempoh (cth 14 minggu × 2 sesi).
3. Skrol **Progress Mingguan** — setiap minggu tunjuk status sesi (Hadir, Ditempah, Tidak Hadir, dll.).
4. Klik satu minggu untuk buka butiran sesi; klik **📋 Lihat butiran & bekalan minggu ini** untuk nota coach, vitals, kepatuhan, bimbingan & bekalan.
5. Untuk sesi online, klik **🎥 Sertai Sesi Dalam Talian** (link Gmeet) pada minggu berkenaan.
6. Perlu tukar tarikh? Klik **Reschedule** / **Tempah** pada sesi tersebut.
7. Buka **Jadual Harian** untuk tick aktiviti harian; buka **Bacaan Saya** untuk catat vitals sendiri.

> Treatment Plan dijana **automatik** dari data pakej anda. Jika pakej aktif tapi pelan belum siap, halaman akan cuba siapkan sendiri — kalau gagal, hubungi coach/staff.

---

## 5. Apa yang anda boleh / tidak boleh ubah

Halaman ini banyak **VIEW** (lihat sahaja). Jadual di bawah jelaskan mana satu anda kawal sendiri.

### A. Pelan Rawatan — `plan.html`
| Item | Anda boleh ubah? | Nota |
|------|------------------|------|
| Setup jadual (pasangan hari + jam) | ✅ **Ya** (sekali, kali pertama) | Pilih **Jumaat + Sabtu** atau **Sabtu + Ahad**, dan jam setiap hari. Sistem auto-jadual sesi seluruh tempoh. |
| Tempah / Reschedule sesi | ✅ **Ya** | Klik **Tempah** (sesi belum dijadual) atau **Reschedule** (sesi ditempah). Hanya hari rawatan dibenarkan (lazimnya Jumaat/Sabtu/Ahad). |
| Skop reschedule | ✅ **Ya** | Pilih **"Tukar semua sesi seterusnya"** (auto-shift minggu lain) atau **"Tukar minggu ini sahaja"**. |
| Statistik (Total/Selesai/Progres/Aktif minggu) | ❌ Auto | Dikira sistem dari status sesi. |
| Status sesi (Hadir/Tidak Hadir/Selesai) | ❌ Coach | Coach tanda hadir semasa sesi. Sesi yang terlepas tarikh auto-jadi **Tidak Hadir**. |

### B. Butiran Mingguan — `plan-week.html`
| Item | Anda boleh ubah? | Nota |
|------|------------------|------|
| Checklist **Matlamat BPS-S** (Bio/Psycho/Social/Spiritual) | ✅ **Ya** | Tick matlamat yang anda dah laksanakan minggu ini. |
| Checklist **Goals & Homework** dari coach | ✅ **Ya** | Tick bila siap (disimpan dalam browser anda). |
| **Feedback Minggu Ini** (rating Coach & Bekalan + komen) | ✅ **Ya** | Beri bintang + komen; boleh tukar semula. |
| **Nota Coach / Nota Doktor** | ❌ Lihat sahaja | Direkod coach/doktor. Klik kad untuk baca penuh. |
| **Bacaan Vitals** minggu ini | ❌ Lihat sahaja | Direkod semasa sesi (untuk tambah sendiri → guna **Bacaan Saya**). |
| **Kepatuhan Rawatan** (madu, nafas, terapi bumi, dll.) | ❌ Lihat sahaja | Direkod coach semasa sesi. |
| **Bimbingan & Bekalan Minggu Ini** | ❌ Lihat sahaja | Tunjuk status tugasan & bekalan yang coach tanda semasa sesi. |
| **🎥 Sertai Sesi Dalam Talian** (Gmeet) | — | Butang muncul untuk sesi online yang **belum berlangsung**. |

> Jika sesi minggu itu **belum berlaku**, butiran (nota, vitals, rekod) belum tersedia dan kad akan dipudarkan — maklumat muncul selepas sesi berlangsung.

### C. Jadual Harian — `routine.html`
| Item | Anda boleh ubah? | Nota |
|------|------------------|------|
| Tick aktiviti harian (selesai/belum) | ✅ **Ya** | Tab **Hari Ini**. Reminder muncul automatik bila tiba masa aktiviti. |
| **✏️ Edit Jadual** (masa + aktiviti) | ✅ **Ya** | Ubah suai jadual peribadi anda. |
| **↺ Reset Default** | ✅ **Ya** | Kembali ke jadual default dari pakej (perubahan anda hilang). |
| Jadual default (template) | ❌ Datang dari pakej | Asalnya dari pakej; muncul kalau anda belum ubah suai. |
| Tab **Sejarah** (7/14/30/90 hari) | ❌ Lihat sahaja | Peratus kepatuhan harian dijejak automatik. |

### D. Bacaan Saya (vitals) — `vitals.html`
| Item | Anda boleh ubah? | Nota |
|------|------------------|------|
| **+ Catat Bacaan Sendiri** | ✅ **Ya** | BP, nadi, berat, tinggi, gula darah (RBS), HbA1c + nota. BMI auto dikira. |
| **✏️ Edit** bacaan | ✅ **Ya** (terhad) | Hanya bacaan **sendiri** bertarikh **hari ini** boleh diedit. |
| Bacaan oleh **Staf Konsultasi** | ❌ Lihat sahaja | Direkod staf semasa sesi. |
| Kad ringkasan terkini & jadual sejarah | ❌ Auto | Tapis ikut sumber: Semua / Staf / Rekod Sendiri. |

---

## 6. Apa jadi lepas anda buat tindakan
1. **Setup jadual:** sistem tulis pilihan (`preferred_pair`, jam) ke **`psy_treatment_plans`** dan jana semua sesi ke **`psy_plan_weekly_progress`** (status `booked`, atau `reschedule` kalau jatuh pada cuti konsultasi). Audit: `plan.schedule_setup`.
2. **Tempah / Reschedule:** cipta/kemaskini janji temu (`psy_appointments`) + kemaskini sesi (`psy_plan_weekly_progress`). Pilih "tukar semua" akan **cascade shift** sesi seterusnya. Audit: `plan.session_booked` / `plan.session_rescheduled` / `plan.cascade_shift`.
3. **Sesi terlepas:** sesi yang lepas tarikh tanpa hadir auto-tanda **Tidak Hadir** (`cancel`); sistem cadang tarikh ganti. Coach boleh buka **minggu tambahan berbayar** — banner kuning muncul dengan butang **Bayar** (lihat [peraturan absence](../../sistem/03-modul.md)).
4. **Checklist matlamat BPS-S:** tick ditulis ke **`psy_plan_check_ins`**; progress bar dikemaskini.
5. **Feedback minggu:** ditulis ke **`psy_feedback`** (`feedback_type='weekly'`) — sama sumber yang staf lihat.
6. **Jadual Harian (edit):** jadual peribadi disimpan ke **`psy_patients.daily_schedule`**; tick harian ke **`psy_daily_completions`**.
7. **Bacaan sendiri:** ditulis ke **`psy_vitals`** (`source='patient_self'`), auto-tag plan & minggu semasa; tinggi dikemaskini pada rekod pesakit.

---

## 7. Masalah biasa
| Mesej / gejala | Sebab & penyelesaian |
|----------------|----------------------|
| "Belum Ada Pelan Rawatan" | Belum ada pakej aktif (atau dah luput). Pilih pakej di [pakej](pakej.html) & bayar. |
| "Pelan Rawatan Akan Disiapkan" | Pakej aktif tapi pelan belum dijana. Refresh; kalau berterusan, hubungi coach/staff. |
| Wizard setup muncul lagi | Anda belum sahkan jadual. Pilih pasangan hari + jam, semak preview, tekan **Sahkan & Auto-Jadual**. |
| "Hanya Jumaat, Sabtu, Ahad dibenarkan" | Sesi rawatan hanya pada hari yang dibenarkan. Pilih hari yang sah. |
| "Konsultasi tutup pada tarikh ini" | Tarikh jatuh pada cuti konsultasi. Pilih hari lain. |
| Banner kuning "Sesi terlepas — bayar untuk lanjutkan" | Anda terlepas sesi; minggu tambahan dibuka. Tekan **Bayar Sekarang** atau hubungi coach. |
| Nota/vitals minggu kosong & kad pudar | Sesi belum berlangsung. Maklumat muncul selepas sesi. |
| Tak nampak butang **🎥 Sertai Sesi** | Butang hanya untuk sesi **online** yang **akan datang** dan ada link Gmeet. Sesi lepas/F2F tiada butang. |
| Tak boleh edit bacaan lama | Hanya bacaan **sendiri** bertarikh **hari ini** boleh diedit. Bacaan staf & bacaan lama dikunci. |
| Jadual Harian kosong / "perlu pakej aktif" | Perlu pakej aktif + jadual harian dari pakej. Tekan **✏️ Edit Jadual** untuk tambah sendiri. |

---

## 8. Rujukan teknikal
- Page: [`roles/patient/plan.html`](../../../roles/patient/plan.html) · setup wizard `confirmScheduleSetup()`, tempah `confirmBooking()`, auto-miss `autoMarkMissedAndExtend()`
- Page: [`roles/patient/plan-week.html`](../../../roles/patient/plan-week.html) · `loadWeekDetail()`, checklist `toggleCheckIn()`, feedback `submitWeekFeedback()`
- Page: [`roles/patient/routine.html`](../../../roles/patient/routine.html) · `saveDailyEdit()`, `toggleDailyDone()`
- Page: [`roles/patient/vitals.html`](../../../roles/patient/vitals.html) · `saveSelfVitals()`
- Jadual: `psy_treatment_plans`, `psy_plan_weekly_progress`, `psy_plan_check_ins`, `psy_feedback`, `psy_daily_completions`, `psy_vitals`, `psy_appointments`, `psy_plan_compliance` (lihat [02-pangkalan-data.md](../../sistem/02-pangkalan-data.md))
