-- Diagnostik: kenapa "SEED DEMO" tak keluar di kad Sesi 1:1 Hakeema
SELECT
  r.id, r.meet_date, r.status, r.week_number,
  p.mrn, p.coach_id,
  coach.full_name AS nama_coach
FROM psy_clinical_referrals r
JOIN psy_patients p ON p.id = r.patient_id
LEFT JOIN psy_profiles coach ON coach.id = p.coach_id
WHERE r.referred_by_name = 'SEED DEMO';
