-- ============================================================
-- ISW SHIFA HUB — MOCKUP / SEED DATA
-- ⚠️ Sign up dulu sekurang-kurangnya 1 patient + 1 staff
-- (admin perlu create staff dari Manage Staff page atau bagi role staff manually dalam profiles)
-- ============================================================

DO $$
DECLARE
  v_patient_user_id UUID;
  v_staff_user_id UUID;
  v_patient_id UUID;
  v_patient_name TEXT;
  v_staff_name TEXT;
  v_plan_id UUID;
BEGIN
  -- Auto-detect first patient and first staff
  SELECT id, full_name INTO v_patient_user_id, v_patient_name
    FROM profiles WHERE role = 'patient' LIMIT 1;
  SELECT id, full_name INTO v_staff_user_id, v_staff_name
    FROM profiles WHERE role = 'staff' LIMIT 1;

  IF v_patient_user_id IS NULL THEN
    RAISE EXCEPTION 'Tiada patient. Sila daftar akaun patient dulu.';
  END IF;
  IF v_staff_user_id IS NULL THEN
    RAISE EXCEPTION 'Tiada staff. Sila daftar/cipta akaun staff dulu.';
  END IF;

  -- ==================== PATIENT RECORD ====================
  INSERT INTO patients (
    user_id, mrn, ic_number, date_of_birth, gender, address,
    emergency_contact_name, emergency_contact_phone,
    insurance_provider, insurance_policy, referral_source, status
  ) VALUES (
    v_patient_user_id,
    'P-2026-' || LPAD(FLOOR(RANDOM() * 9999)::TEXT, 4, '0'),
    '900512-10-1234', '1990-05-12', 'F',
    'No. 12, Jln Bunga Raya 3, 43000 Kajang, Selangor',
    'Ahmad bin Abdullah (suami)', '+60 19-876 5432',
    'Prudential Gold', 'PGL-223344',
    'Walk-in (Dr. Farhan KPJ Kajang)', 'active'
  )
  ON CONFLICT DO NOTHING
  RETURNING id INTO v_patient_id;

  IF v_patient_id IS NULL THEN
    SELECT id INTO v_patient_id FROM patients WHERE user_id = v_patient_user_id LIMIT 1;
  END IF;

  -- ==================== TREATMENT PLAN (BPS-S) ====================
  INSERT INTO treatment_plans (
    patient_id, doctor_id, name, template, duration_weeks, current_week,
    bio_goals, psycho_goals, social_goals, spiritual_goals, status
  ) VALUES (
    v_patient_id, v_staff_user_id,
    'BPS-S Holistic Plan — 12 Minggu',
    'wellness_core_90', 12, 4,
    '["Santapan Fitrah (daily)","Jus halia 3x/week","Madu Shifa 1tbsp/pagi","Blood test month 2"]'::jsonb,
    '["CBT dengan Coach (weekly)","Journaling (daily)","Breathing 4-7-8 (2x/hari)","Mood tracker harian"]'::jsonb,
    '["Family support circle","Group session 2x/month","Community kelas wanita","Accountability partner"]'::jsonb,
    '["Zikir Al-Mathurat pagi/petang","Solat hajat mingguan","Tadarus 1 juz/week","Doa syifa harian"]'::jsonb,
    'active'
  ) RETURNING id INTO v_plan_id;

  -- ==================== APPOINTMENTS ====================
  INSERT INTO appointments (patient_id, staff_id, patient_name, staff_name, service, appointment_time, duration_min, status, room) VALUES
  (v_patient_id, v_staff_user_id, v_patient_name, v_staff_name, 'Follow-up Consultation', NOW() + INTERVAL '3 days' + INTERVAL '10 hours 30 minutes', 45, 'scheduled', 'Room 2, ISW Kajang'),
  (v_patient_id, v_staff_user_id, v_patient_name, v_staff_name, 'Coaching Session (Psycho)', NOW() + INTERVAL '7 days' + INTERVAL '14 hours', 60, 'scheduled', 'Telehealth'),
  (v_patient_id, v_staff_user_id, v_patient_name, v_staff_name, 'Vitals Check-up (Nurse)', NOW() + INTERVAL '14 days' + INTERVAL '9 hours', 20, 'scheduled', 'Room 1'),
  (v_patient_id, v_staff_user_id, v_patient_name, v_staff_name, 'Initial Consultation', NOW() - INTERVAL '28 days', 60, 'completed', 'Room 1'),
  (v_patient_id, v_staff_user_id, v_patient_name, v_staff_name, 'Onboarding BPS-S', NOW() - INTERVAL '21 days', 60, 'completed', 'Room 3'),
  (v_patient_id, v_staff_user_id, v_patient_name, v_staff_name, 'Coaching Week 2', NOW() - INTERVAL '14 days', 45, 'completed', 'Telehealth'),
  (v_patient_id, v_staff_user_id, v_patient_name, v_staff_name, 'Coaching Week 3', NOW() - INTERVAL '7 days', 45, 'completed', 'Room 2');

  -- ==================== VITALS (history 3 bulan) ====================
  INSERT INTO vitals (patient_id, recorded_by, bp_systolic, bp_diastolic, heart_rate, spo2, temperature, weight, height, bmi, waist_cm, rbs, phq2_score, gad2_score, notes, created_at) VALUES
  (v_patient_id, v_staff_user_id, 130, 88, 82, 97.5, 36.9, 64.0, 160, 25.0, 82, 5.8, 3, 4, 'Baseline reading. BP slightly elevated, mood low.', NOW() - INTERVAL '28 days'),
  (v_patient_id, v_staff_user_id, 125, 82, 78, 98.0, 36.8, 63.5, 160, 24.8, 80, 5.5, 2, 3, 'Week 1 — adjusting to plan.', NOW() - INTERVAL '21 days'),
  (v_patient_id, v_staff_user_id, 122, 80, 76, 98.0, 36.7, 62.5, 160, 24.4, 78, 5.4, 1, 2, 'Week 2 — improving. Sleep better.', NOW() - INTERVAL '14 days'),
  (v_patient_id, v_staff_user_id, 120, 78, 74, 98.5, 36.8, 62.0, 160, 24.2, 77, 5.2, 1, 2, 'Week 3 — stable. Mood lifted.', NOW() - INTERVAL '7 days'),
  (v_patient_id, v_staff_user_id, 118, 76, 72, 99.0, 36.8, 61.5, 160, 24.0, 76, 5.0, 0, 1, 'Week 4 — excellent progress.', NOW() - INTERVAL '1 days');

  -- ==================== PRESCRIPTIONS ====================
  INSERT INTO prescriptions (patient_id, doctor_id, patient_name, medication, dosage, frequency, supply_days, status) VALUES
  (v_patient_id, v_staff_user_id, v_patient_name, 'Madu Shifa (Young & Healthy Honey)', '1 sudu besar', 'Pagi selepas sarapan', 30, 'active'),
  (v_patient_id, v_staff_user_id, v_patient_name, 'Jus Halia Concentrate', '50ml diluted', '3x/minggu (Isnin, Rabu, Jumaat)', 30, 'active'),
  (v_patient_id, v_staff_user_id, v_patient_name, 'Magnesium Glycinate', '200mg', 'Sebelum tidur', 30, 'active'),
  (v_patient_id, v_staff_user_id, v_patient_name, 'Vitamin D3', '5000 IU', 'Pagi dengan makanan', 90, 'active');

  -- ==================== SOAP NOTES (3 sesi) ====================
  INSERT INTO soap_notes (patient_id, doctor_id, chief_complaint, hpi, ros_positives, meds_adherence, examination, diagnoses, clinical_reasoning, plan_medications, plan_labs, follow_up, status, signed_at, created_at) VALUES
  (v_patient_id, v_staff_user_id,
    'Mood rendah, susah tidur, stress kerja',
    'Pesakit perempuan 35 tahun mengalami mood rendah selama 3 bulan. Tidur terganggu (~5 jam, banyak terjaga). Rasa cemas sebelum kerja. Tiada ide bunuh diri. Keluarga sokong. Tiada appetite changes. Pernah cuba melatonin tapi tak berkesan.',
    'Sleep disturbance, anxiety, fatigue petang',
    'Good (>90%)',
    'GA: alert, well-orientated. CVS S1S2 normal. Resp clear. No focal neuro deficit. PHQ-9: 12 (moderate), GAD-7: 10 (moderate).',
    '["F41.1 — Generalized Anxiety Disorder","Insomnia (stress-related)","Mild metabolic dysregulation"]'::jsonb,
    'Pesakit sesuai untuk pendekatan BPS-S holistik. Mula dengan lifestyle (Santapan Fitrah, herba), spiritual practice (zikir, solat hajat), dan support system (group session). Tidak ada indikasi untuk SSRI dahulu — pantau 4 minggu.',
    '["Madu Shifa 1tbsp OD","Magnesium 200mg HS","Vitamin D 5000IU OD"]'::jsonb,
    '["Lipid profile fasting","Vitamin D level","Thyroid panel"]'::jsonb,
    '2 minggu', 'signed', NOW() - INTERVAL '28 days', NOW() - INTERVAL '28 days'),

  (v_patient_id, v_staff_user_id,
    'Follow-up BPS-S — Week 2',
    'Mood improving. Tidur dah 6-7 jam. Amal zikir Al-Mathurat konsisten. Santapan Fitrah dah jadi rutin. Cemas masa kerja dah berkurangan. Ada satu episod menangis minggu lepas masa ingat allahyarham bapa.',
    'Mood lifting, energy improving',
    'Good (>90%)',
    'PHQ-9: 8 (mild), GAD-7: 6 (mild). BP stable. Weight loss 1kg. Patient looks brighter.',
    '["F41.1 — improving","Adjustment grief reaction"]'::jsonb,
    'Response sangat positif kepada pendekatan BPS-S. Spiritual practice + lifestyle changes membawa hasil. Tambah journaling untuk grief processing. Continue current regimen.',
    '["Continue current Rx"]'::jsonb,
    '[]'::jsonb,
    '4 minggu', 'signed', NOW() - INTERVAL '14 days', NOW() - INTERVAL '14 days'),

  (v_patient_id, v_staff_user_id,
    'Coaching follow-up + medication review',
    'Pesakit melaporkan kestabilan emosi yang baik. Tidur 7-8 jam konsisten. PHQ-9 menurun ke 4 (minimal). Yakin dengan tawakkal dan ibadah. Masih ada sedikit cemas masa deadline kerja.',
    'Coping skills improving',
    'Good (>90%)',
    'PHQ-9: 4 (minimal), GAD-7: 4 (minimal). All vitals normal.',
    '["F41.1 — well-controlled","Stress management — improving"]'::jsonb,
    'Pesakit menunjukkan recovery yang baik. Kekalkan regimen dan tambah breathing exercise sebelum tidur untuk anxiety. Tiada perubahan ubat.',
    '["Continue all"]'::jsonb,
    '["FBC + Renal panel (annual)"]'::jsonb,
    '6 minggu', 'signed', NOW() - INTERVAL '7 days', NOW() - INTERVAL '7 days');

  -- ==================== COACHING SESSIONS ====================
  INSERT INTO coaching_sessions (patient_id, coach_id, patient_name, session_type, pillar, session_date, duration_min, mood_pre, mood_post, notes, goals_discussed, homework, status) VALUES
  (v_patient_id, v_staff_user_id, v_patient_name, 'Onboarding', 'psycho',
    NOW() - INTERVAL '21 days', 60, 4, 7,
    'Sesi onboarding BPS-S. Establish rapport, terangkan 4 pillar holistik. Pesakit receptive dan committed. Discuss expectations dan goals.',
    '["Tetapkan routine zikir pagi","Journal setiap malam (3 perkara syukur)","Breathing 4-7-8 sebelum tidur"]'::jsonb,
    '["Tulis 3 rasa syukur setiap hari","Rakam mood score 1-10","Beli buku zikir Al-Mathurat"]'::jsonb,
    'completed'),

  (v_patient_id, v_staff_user_id, v_patient_name, 'Weekly Check-in', 'spiritual',
    NOW() - INTERVAL '14 days', 45, 5, 8,
    'Amalan zikir konsisten. Sleep dah baik. Discuss peranan tawakkal dalam penyembuhan. Pesakit mula faham hubungan ibadah dengan kesihatan mental.',
    '["Refine spiritual practice","Introduce tadabbur al-Quran","Solat hajat mingguan"]'::jsonb,
    '["Baca 1 ayat + tafsir harian","Solat hajat malam Khamis","Hadhir kelas tafsir online"]'::jsonb,
    'completed'),

  (v_patient_id, v_staff_user_id, v_patient_name, 'Weekly Check-in', 'social',
    NOW() - INTERVAL '7 days', 45, 6, 7,
    'Discuss support system. Suami sangat supportive. Brainstorm community activities untuk perkukuhkan support. Patient setuju nak join usrah wanita.',
    '["Join usrah wanita di surau"]'::jsonb,
    '["Daftar usrah wanita Sabtu","Family wellness weekend planning"]'::jsonb,
    'completed'),

  (v_patient_id, v_staff_user_id, v_patient_name, 'Weekly Check-in', 'bio',
    NOW() - INTERVAL '1 days', 45, 7, 8,
    'Berat dah turun 2.5kg. Energy levels naik. Nutrition consistent. Discuss tambah exercise routine ringan.',
    '["Add walking 20 min/hari","Consider yoga ringan"]'::jsonb,
    '["Walk 20 min selepas subuh setiap hari","Try yoga video YouTube 3x/minggu"]'::jsonb,
    'completed');

  -- ==================== LAB ORDERS ====================
  INSERT INTO lab_orders (patient_id, doctor_id, patient_name, panel, results, flags, status, ordered_at, resulted_at) VALUES
  (v_patient_id, v_staff_user_id, v_patient_name, 'Basic Metabolic Panel',
    '{"glucose_fasting": 5.2, "ldl": 2.8, "hdl": 1.4, "triglycerides": 1.1, "tsh": 2.1, "free_t4": 14.2}'::jsonb,
    NULL, 'reviewed',
    NOW() - INTERVAL '28 days', NOW() - INTERVAL '25 days'),
  (v_patient_id, v_staff_user_id, v_patient_name, 'Vitamin D + B12',
    '{"vit_d": 22, "b12": 320}'::jsonb, 'Vit D rendah (deficient)',
    'reviewed', NOW() - INTERVAL '28 days', NOW() - INTERVAL '24 days'),
  (v_patient_id, v_staff_user_id, v_patient_name, 'FBC + Renal Panel',
    NULL, NULL, 'ordered', NOW() - INTERVAL '2 days', NULL);

  -- ==================== KYC SAMPLES (untuk staff review) ====================
  INSERT INTO kyc_submissions (patient_name, ic_number, phone, email, address, referral_source,
    consent_data_processing, consent_health_records, consent_research, status) VALUES
  ('Aminah binti Hassan', '880101-14-5678', '+60 12-345 6789', 'aminah.h@gmail.com',
    'Subang Jaya, Selangor', 'Walk-in', true, true, false, 'pending'),
  ('Hasrul bin Razali', '750505-08-1234', '+60 19-888 1234', 'hasrul@email.com',
    'Shah Alam, Selangor', 'Friend referral', true, true, true, 'pending'),
  ('Nurul Syafiqah', '950820-10-2345', '+60 13-555 6789', 'syafiqah@gmail.com',
    'Cheras, KL', 'Instagram ad', true, true, false, 'pending');

  -- ==================== RISK ALERT (sample) ====================
  INSERT INTO risk_alerts (patient_id, patient_name, created_by, created_by_name,
    severity, category, description, status) VALUES
  (v_patient_id, v_patient_name, v_staff_user_id, v_staff_name,
    'moderate', 'missed_checkin',
    'Patient missed 2 daily check-ins berturut. Last mood entry 5/10. Pertimbang follow-up call.',
    'open');

  -- ==================== DAILY CHECK-INS (mood history) ====================
  INSERT INTO daily_checkins (patient_id, checkin_date, mood_score, energy_score, sleep_quality, sleep_hours, symptoms, activities, notes) VALUES
  (v_patient_id, CURRENT_DATE - 6, 5, 4, 5, 5.5,
    '["😣 Sakit kepala","🥺 Cemas / risau","🥱 Insomnia"]'::jsonb,
    '["🧘 Zikir pagi","🍯 Ambil madu/ubat"]'::jsonb,
    'Stress kerja, deadline. Tidur kurang.'),
  (v_patient_id, CURRENT_DATE - 5, 6, 5, 6, 6.0,
    '["😴 Letih / lemah"]'::jsonb,
    '["🧘 Zikir pagi","🕌 Solat penuh","💧 Minum air cukup"]'::jsonb,
    'Lebih tenang hari ni.'),
  (v_patient_id, CURRENT_DATE - 4, 7, 7, 7, 7.0,
    '[]'::jsonb,
    '["🧘 Zikir pagi","🕌 Solat penuh","🥗 Santapan Fitrah","🍯 Ambil madu/ubat","🫁 Breathing exercise"]'::jsonb,
    'Hari yang baik. Berjaya practice breathing exercise.'),
  (v_patient_id, CURRENT_DATE - 3, 8, 7, 8, 7.5,
    '[]'::jsonb,
    '["🧘 Zikir pagi","🕌 Solat penuh","🚶 Berjalan / bersenam","🥗 Santapan Fitrah","📖 Tadarus","😊 Journaling"]'::jsonb,
    'Routine penuh hari ni. Rasa berkat dan tenang.'),
  (v_patient_id, CURRENT_DATE - 2, 7, 6, 7, 7.0,
    '["😣 Sakit kepala"]'::jsonb,
    '["🧘 Zikir pagi","🕌 Solat penuh","🥗 Santapan Fitrah"]'::jsonb,
    'Sedikit sakit kepala petang ni.'),
  (v_patient_id, CURRENT_DATE - 1, 8, 8, 8, 7.5,
    '[]'::jsonb,
    '["🧘 Zikir pagi","🕌 Solat penuh","🚶 Berjalan / bersenam","🥗 Santapan Fitrah","🍯 Ambil madu/ubat","💧 Minum air cukup","👨‍👩‍👧 Masa dengan keluarga"]'::jsonb,
    'Masa berkualiti dengan keluarga.');

  RAISE NOTICE '✅ Seed data berjaya. Patient: %, Staff: %, MRN dicipta untuk patient.', v_patient_name, v_staff_name;
END $$;
