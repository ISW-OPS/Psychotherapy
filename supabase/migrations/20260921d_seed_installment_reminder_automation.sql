-- Seed automasi "Peringatan Ansuran" (Sistem Automasi) — 2 mesej: 7 hari & 2 hari sebelum due date.
-- Dicipta sebagai DRAF (tidak aktif) — semak teks dalam halaman Automasi kemudian aktifkan.
-- Pautan HitPay + invois PDF dilampirkan automatik bila templat guna {{pautan}} (automations-runner).
-- Jangan hidupkan serentak dgn Auto Mesej "installment_reminder" (psy_auto_messages) — mesej berganda.
-- Idempotent: tak dicipta semula kalau automasi bernama sama sudah wujud.
do $$
declare v_id uuid;
begin
  if exists (select 1 from psy_automations where name = 'Peringatan Ansuran Pakej') then
    return;
  end if;

  insert into psy_automations
    (name, description, is_active, status, trigger_category, trigger_event, trigger_timing,
     conditions_enabled, conditions, actions, message_channel, run_mode)
  values
    ('Peringatan Ansuran Pakej',
     'Ingatkan pesakit sebelum ansuran pakej jatuh tempoh: 7 hari dan 2 hari sebelum. Sertakan pautan bayaran HitPay + invois PDF.',
     false, 'draft', 'installment', 'installment_reminder', '{"when":"before"}'::jsonb,
     false, '[]'::jsonb, '["whatsapp"]'::jsonb, 'whatsapp', 'always')
  returning id into v_id;

  insert into psy_automation_messages
    (automation_id, position, send_mode, day_offset, send_time, content_type, message_text)
  values
    (v_id, 1, 'specific_time', 7, '10:00', 'text',
     E'Salam {{nama}} 👋\n\nMakluman: ansuran *{{ansuran}}* pakej rawatan anda (RM {{jumlah}}) akan tamat tempoh pada *{{tarikh_due}}*.\n\nInvois dilampirkan. Anda boleh bayar melalui pautan selamat ini:\n{{pautan}}\n\nTerima kasih — ISW'),
    (v_id, 2, 'specific_time', 2, '10:00', 'text',
     E'Salam {{nama}} 👋\n\nPeringatan: ansuran *{{ansuran}}* (RM {{jumlah}}) akan tamat tempoh pada *{{tarikh_due}}*.\n\nSila selesaikan bayaran sebelum tarikh itu untuk mengelakkan tempahan sesi disekat:\n{{pautan}}\n\nTerima kasih — ISW');
end $$;
