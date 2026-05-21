# Soalan Meeting Izzah — Modul Risk Alert & Kepatuhan

**Tujuan**: Tentukan definisi & kriteria untuk dua modul yang sedang **greyed-out** sehingga keputusan diambil:
1. **Risk Alert** ("Pesakit Perlu Tindakan Segera" dalam Dashboard Coach)
2. **Kepatuhan** ([kepatuhan.html](../roles/staff/kepatuhan.html), kad "Check-in 7 Hari" dalam Dashboard, column "Status Kepatuhan" dalam table pesakit)

---

## A. Konsep Asas

1. **Apakah "risk"** dalam konteks Ibnu Sina Wellness?
   - Risiko klinikal (BP tinggi, gula tinggi, simptom bahaya)?
   - Risiko keciciran rawatan (patient drop-out)?
   - Risiko ketidakpatuhan (tak ambil madu, tak buat protokol)?
   - Risiko emotional/mental (mood rendah, stress)?
   - Gabungan kesemuanya?

2. **Siapa yang patut bertindak** bila ada risk alert?
   - Coach pesakit terus?
   - Doktor untuk semakan klinikal?
   - Manager untuk escalation?
   - Semua sekali (berbeza ikut jenis risk)?

3. **Bila risk dianggap "Segera"** vs boleh tangguh?
   - Tempoh tindak balas: dalam berapa jam/hari?
   - Adakah ada SLA berbeza untuk severity berbeza?

---

## B. Kriteria & Severity

4. **Severity level** — adakah perlu 4 tingkat (`low / medium / high / critical`) seperti dalam schema?
   - Atau cukup 2 tingkat (Amaran / Kritis) sahaja?
   - Atau 3 (Info / Amaran / Kritis)?

5. **Threshold untuk setiap severity** — boleh izzah definisikan?

   Contoh rangka soalan (bukan cadangan):
   - **Kritis**: bila apa berlaku? (cth: BP > 180/110? Tiada check-in 7 hari? Tiada hadir 2 sesi berturut?)
   - **Amaran**: bila apa berlaku? (cth: BP > 160/100? Tiada check-in 3 hari? Mood < 3/10?)
   - **Info**: hanya untuk maklumat sahaja?

6. **Multi-signal triggers** — adakah satu signal cukup, atau perlu gabungan?
   - Contoh: BP tinggi SAHAJA = amaran, atau BP tinggi + mood rendah baru kritis?

---

## C. Source Data

7. **Data apa yang Izzah anggap relevan untuk pantau?** Pilih dari yang sistem dah rekod:

   | Data | Rekod harian/mingguan? | Boleh jadi signal? |
   |---|---|---|
   | Daily check-in (mood, energy, sleep, simptom) | Harian | Ya/Tidak? |
   | Kepatuhan protokol (madu, nafas, terapi bumi, kelapa, kolon, berjemur, pantang) | Mingguan | Ya/Tidak? |
   | Vital signs (BP, HR, BMI, berat) | Mingguan/setiap sesi | Ya/Tidak? |
   | Status sesi (hadir/cancel/no-show) | Mingguan | Ya/Tidak? |
   | Feedback pesakit (rating + komen) | Mingguan | Ya/Tidak? |
   | Skor BPS-S (bio/psycho/social/spiritual goals) | Mingguan | Ya/Tidak? |

8. **Adakah ada data luar yang perlu**, yang sistem belum rekod?
   - HbA1c, lipid profile, lab results?
   - Soalan PHQ-9 / GAD-7 (mental health screening)?
   - Lain-lain?

---

## D. Workflow

9. **Auto vs Manual** — bila alert wujud:
   - **Auto** (sistem kira dari data → cipta alert sendiri)?
   - **Manual** (coach/doktor flag pesakit sebagai berisiko)?
   - **Gabungan** (auto detect + boleh manual tambah)?

10. **Apabila ada alert**, apa coach perlu buat?
    - Acknowledge (tandakan dah baca) — sudah ada
    - Resolve (tandakan sudah diatasi) — sudah ada
    - Eskalasi ke doktor — perlu ke?
    - Catat tindakan yang diambil — perlu ke?

11. **Notifikasi** — perlu hantar ke mana?
    - In-app notification untuk coach?
    - WhatsApp/SMS untuk coach kalau Kritis?
    - Email harian summary?

12. **Lifecycle alert**:
    - Bila alert auto-resolve? (cth: patient check-in semula → alert "tiada check-in" hilang sendiri?)
    - Atau coach kena manually resolve setiap alert?

---

## E. Pemaparan UI

13. **Dashboard Coach** — sekarang panel tunjuk top 3. Berapa banyak Izzah nak nampak?

14. **Patient Hub** — bila buka pesakit individu, perlu tunjuk semua sejarah alert dia?

15. **Risk report** — perlu ada page khas untuk senarai semua alert (sudah ada `risk.html`)?

---

## F. Prioriti & Skop Sprint

16. Adakah modul Risk Alert ini **prioriti sprint terdekat**, atau boleh tangguh ke kemudian?

17. Kalau prioriti — bermula dari rule yang **paling mudah/jelas dulu** (cth: tiada check-in X hari)?

18. Adakah Izzah ada **contoh dari klinik lain** atau standard amalan psychotherapy yang patut dirujuk?

---

---

## G. Modul Kepatuhan

19. **Berapa jenis kepatuhan** yang ISW pantau? Yang saya nampak dari mockup awal:
    - **Kategori OB**: Pesakit A (Disiplin & Patuh 100%) / Pesakit B (Separuh Patuh — tak jaga pantang makan) / Pesakit C (Tidak patuh)
    - Adakah klasifikasi ini formal? Atau hanya rujukan dalaman?

20. **Kepatuhan dikira berdasarkan apa?** Jujur, sekarang ada DUA tafsiran berbeza dalam sistem yang konflik:
    - **Session-based**: % sesi hadir vs total sesi (cara `kepatuhan.html` kira sekarang)
    - **Check-in based**: % hari pesakit check-in vs 7 hari (cara dashboard kira)
    - **Protokol-based**: % protokol diikut (madu, nafas, terapi bumi, kelapa, kolon, berjemur, pantang)
    - **Gabungan**: weighted score dari semua di atas
    - **Manual categorization**: coach/doktor flag pesakit ikut kategori OB (A/B/C) selepas review

    **Mana satu yang betul untuk ISW?** Atau perlu ada beberapa metric berasingan?

21. **Kalau guna kategori OB (A/B/C)** — siapa yang assign kategori ni?
    - Coach selepas observation?
    - Auto dari data?
    - Doktor selepas semakan?
    - Pesakit sendiri (self-assessment)?

22. **Threshold "patuh" vs "tidak patuh"** — kalau guna metric automatik, apa cut-off?
    - Patuh 100%: macam mana ditakrifkan? Semua check-in 7/7? Semua sesi hadir? Semua protokol komplit?
    - Separuh Patuh: berapa peratus? 50-79%? Bergantung pada apa?
    - Tidak Patuh: di bawah berapa peratus?

23. **Period pengiraan** — kepatuhan dikira untuk:
    - Mingguan? Bulanan? Selama tempoh rawatan keseluruhan?
    - Adakah ada "rolling 7 days" atau snapshot pada masa tertentu?

24. **Pantang makanan** — disebut dalam kategori OB sebagai signal penting. Sekarang sistem rekod sebagai boolean (Ya/Tidak) sekali seminggu dalam `psy_plan_compliance.pantang`. Cukup ke, atau perlu lebih detail (jenis makanan dilanggar)?

25. **Bagaimana kepatuhan dipaparkan**?
    - Pada coach: per-pesakit dengan status A/B/C, atau % skor?
    - Pada doktor: ringkasan agregat untuk semua pesakit dia review?
    - Pada manager: trend mingguan/bulanan untuk seluruh klinik?

---

## Maklumat untuk dibawa ke meeting

### Risk Alert
- Schema `psy_risk_alerts` sudah wujud dengan column `severity` (low/medium/high/critical), `category`, `description`, `status` (open/acknowledged/resolved).
- Page [risk.html](../roles/staff/risk.html) sudah boleh paparkan dan acknowledge alert — tinggal logik untuk **cipta** alert sahaja yang belum.
- Panel "Pesakit Perlu Tindakan Segera" dalam Dashboard Coach diset "Akan Datang".

### Kepatuhan
- [kepatuhan.html](../roles/staff/kepatuhan.html) — keseluruhan page di-greyed-out dengan placeholder "Modul Kepatuhan Sedang Disediakan".
- Kad "Check-in 7 Hari" dalam Dashboard Coach — kekal aktif, tapi nama dah ditukar dari "Kepatuhan" supaya jelas ia khas untuk check-in harian sahaja (bukan kepatuhan keseluruhan).
- Column "Status Kepatuhan" dalam table "Pesakit Saya" Dashboard Coach — diset "Menunggu kriteria".
- Panel "Trend Kepatuhan" dalam Dashboard Coach — greyed-out.

### Data yang sistem dah ada untuk kira kepatuhan
- `psy_daily_checkins`: mood, energy, sleep, simptom (harian)
- `psy_plan_compliance`: madu_sudu, nafas_kali, bumi_minit, kelapa_kali, kolon_kali, berjemur (bool), pantang (bool) — mingguan
- `psy_plan_weekly_progress`: status sesi (hadir/cancel/reschedule) — mingguan
- `psy_vitals`: BP, HR, BMI — setiap sesi
- `psy_weekly_feedback`: rating + komen — mingguan

**Tarikh meeting**: 26 Mei 2026
