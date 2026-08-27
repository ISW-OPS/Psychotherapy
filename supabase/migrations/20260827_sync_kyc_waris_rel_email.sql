-- Patch sync_kyc_to_patient() supaya emergency_contact_relationship & emergency_contact_email
-- turut disalin dari psy_kyc_submissions ke psy_patients bila KYC diluluskan — dua medan ni
-- sebelum ini tercicir (staff kob-detail.html/patient-form.html tak nampak Hubungan/Emel Waris
-- yang pesakit isi sendiri di pendaftaran.html). Lihat database/schema/04_patients.sql utk
-- versi sumber kebenaran + nota lengkap.

CREATE OR REPLACE FUNCTION sync_kyc_to_patient()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  -- Hanya sync bila status berubah jadi 'approved'
  IF NEW.status = 'approved' AND (OLD.status IS NULL OR OLD.status != 'approved') THEN
    UPDATE psy_patients
    SET
      status                  = 'active',
      full_name               = COALESCE(NULLIF(full_name, ''), NEW.patient_name),
      phone                   = COALESCE(NULLIF(phone, ''), NEW.phone),
      ic_number               = COALESCE(NULLIF(ic_number, ''), NEW.ic_number),
      date_of_birth           = COALESCE(date_of_birth, NEW.date_of_birth),
      gender                  = COALESCE(NULLIF(gender, ''), NEW.gender),
      address                 = COALESCE(NULLIF(address, ''), NEW.address),
      emergency_contact_name  = COALESCE(NULLIF(emergency_contact_name, ''), NEW.emergency_contact_name),
      emergency_contact_phone = COALESCE(NULLIF(emergency_contact_phone, ''), NEW.emergency_contact_phone),
      emergency_contact_relationship = COALESCE(NULLIF(emergency_contact_relationship, ''), NEW.emergency_contact_relationship),
      emergency_contact_email = COALESCE(NULLIF(emergency_contact_email, ''), NEW.emergency_contact_email),
      referral_source         = COALESCE(NULLIF(referral_source, ''), NEW.referral_source),
      medical_condition       = COALESCE(NULLIF(medical_condition, ''), NEW.medical_condition),
      condition_duration      = COALESCE(NULLIF(condition_duration, ''), NEW.condition_duration),
      medical_notes           = COALESCE(NULLIF(medical_notes, ''), NEW.medical_notes)
    WHERE user_id = NEW.user_id;
  END IF;
  RETURN NEW;
END;
$$;
