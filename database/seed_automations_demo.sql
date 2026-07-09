-- SEED DEMO — Automasi + Log Penghantaran + Audience (untuk lihat UI berisi)
-- Idempotent: buang demo lama dulu, kemudian semai semula. Guna pesakit sedia
-- ada. Boleh run di TESTING (& PROD jika mahu demo). Padam bila-bila dgn
-- bahagian DELETE di bawah.
-- ─────────────────────────────────────────────────────────────────────────

-- 1) Bersih demo lama
delete from psy_notification_logs where automation_id in (
  select id from psy_automations where name in (
    'Peringatan Sesi (1 Hari Sebelum)','Peringatan Catatan Harian','Pakej Hampir Tamat',
    'Broadcast Manzil Jumaat','Broadcast Motivasi Isnin','Ucapan Hari Jadi','Peringatan Bayaran Tertunggak'));
delete from psy_automations where name in (
  'Peringatan Sesi (1 Hari Sebelum)','Peringatan Catatan Harian','Pakej Hampir Tamat',
  'Broadcast Manzil Jumaat','Broadcast Motivasi Isnin','Ucapan Hari Jadi','Peringatan Bayaran Tertunggak');
delete from psy_audiences where name in ('Pesakit Aktif Lelaki','Pesakit Ada WhatsApp');

-- 2) Automasi demo
insert into psy_automations (name, description, trigger_category, trigger_event, trigger_timing, conditions_enabled, conditions, actions, message_template, message_channel, status, is_active) values
('Peringatan Sesi (1 Hari Sebelum)','Ingatkan pesakit tentang sesi rawatan esok.','appointment','session_reminder','{"when":"before","value":1,"unit":"day"}'::jsonb,true,'[{"field":"patient_status","value":"active"}]'::jsonb,'["whatsapp","inapp"]'::jsonb,'Salam {{nama}}, ini peringatan sesi rawatan anda esok. Jumpa lagi!','whatsapp','active',true),
('Peringatan Catatan Harian','Ingatkan pesakit isi Catatan Harian setiap malam.','checkin','checkin_missed','{"when":"at"}'::jsonb,false,'[]'::jsonb,'["whatsapp"]'::jsonb,'Salam {{nama}}, jangan lupa isi Catatan Harian anda hari ini ya. 📝','whatsapp','active',true),
('Pakej Hampir Tamat','Ingatkan pesakit pakej hampir tamat.','package','package_expiring','{"when":"before","value":7,"unit":"day"}'::jsonb,true,'[{"field":"patient_status","value":"active"}]'::jsonb,'["whatsapp","email"]'::jsonb,'Salam {{nama}}, pakej rawatan anda akan tamat tidak lama lagi. Hubungi kami untuk sambungan.','whatsapp','active',true),
('Broadcast Manzil Jumaat','Broadcast mingguan ke semua pesakit setiap Jumaat malam.','schedule','recurring_broadcast','{"when":"schedule","days":[5],"time":"20:00"}'::jsonb,false,'[]'::jsonb,'["whatsapp","inapp"]'::jsonb,'Salam {{nama}}, jemput sertai bacaan Manzil bersama malam ini. 🌙','whatsapp','active',true),
('Broadcast Motivasi Isnin','Mesej motivasi setiap Isnin pagi.','schedule','recurring_broadcast','{"when":"schedule","days":[1],"time":"09:00"}'::jsonb,false,'[]'::jsonb,'["inapp"]'::jsonb,'Selamat pagi {{nama}}! Semoga minggu ini penuh keberkatan. 💪','inapp','active',true),
('Ucapan Hari Jadi','Hantar ucapan pada hari lahir pesakit.','patient','birthday','{"when":"at"}'::jsonb,false,'[]'::jsonb,'["whatsapp"]'::jsonb,'Selamat Hari Lahir {{nama}}! 🎉 Semoga sihat sentiasa.','whatsapp','draft',false),
('Peringatan Bayaran Tertunggak','Ingatkan pesakit bayaran tertunggak.','payment','payment_pending','{"when":"after","value":3,"unit":"day"}'::jsonb,false,'[]'::jsonb,'["whatsapp","email"]'::jsonb,'Salam {{nama}}, terdapat bayaran tertunggak untuk pakej anda. Sila selesaikan bila senang.','whatsapp','paused',false);

-- 3) Log penghantaran demo (30 hari) — automasi aktif × pesakit rawak × status
insert into psy_notification_logs (automation_id, patient_id, patient_name, event, channel, status, message, error, created_at, sent_at)
select a.id, p.id, coalesce(p.full_name, p.mrn, 'Pesakit'), a.trigger_event,
  (a.actions->>(floor(random()*jsonb_array_length(a.actions))::int)) as channel,
  st.status,
  'Mesej automatik dihantar kepada pesakit.',
  case when st.status='failed' then 'Nombor tidak sah / tidak dapat dihubungi' else null end,
  p.cdate,
  case when st.status='sent' then p.cdate else null end
from psy_automations a
cross join lateral (
  select pp.id, pp.full_name, pp.mrn,
    (now() - (floor(random()*30)||' days')::interval - (floor(random()*80000)||' seconds')::interval) as cdate
  from psy_patients pp where pp.status not in ('deleted','rejected') order by random() limit 45
) p
cross join lateral (
  select case when random()<0.88 then 'sent' when random()<0.96 then 'failed' else 'pending' end as status
) st
where a.is_active = true
  and a.name in ('Peringatan Sesi (1 Hari Sebelum)','Peringatan Catatan Harian','Pakej Hampir Tamat','Broadcast Manzil Jumaat','Broadcast Motivasi Isnin');

-- 4) Audience demo
insert into psy_audiences (name, description, conditions) values
('Pesakit Aktif Lelaki','Semua pesakit aktif jantina lelaki','[{"field":"patient_status","value":"active"},{"field":"gender","value":"M"}]'::jsonb),
('Pesakit Ada WhatsApp','Pesakit yang ada nombor telefon','[{"field":"has_whatsapp","value":"yes"}]'::jsonb);

select 'Seed demo OK' as status,
  (select count(*) from psy_automations) as automasi,
  (select count(*) from psy_notification_logs) as log;
