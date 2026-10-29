-- 29 Okt 2026 — tarik 2 field GHL tambahan (folder "PT Sytem"):
-- referred_by_affiliate_email, referred_by_affiliate_phone — supaya
-- kob-detail.html seksyen "Affiliate" boleh papar nama+email+phone terus
-- dari GHL (gantikan logik qualified/eligible date psy_referrals yang
-- sebelum ni kosong sentiasa bila tiada padanan nama affiliate).
ALTER TABLE psy_patients ADD COLUMN IF NOT EXISTS referred_by_affiliate_email TEXT;
ALTER TABLE psy_patients ADD COLUMN IF NOT EXISTS referred_by_affiliate_phone TEXT;
