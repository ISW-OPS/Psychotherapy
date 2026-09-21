// ── Pembantu bayaran manual (dikongsi payment-admin / Pesakit Hub / KOB) ─────────
//   iswNowLocalInput()          → nilai lalai <input type="datetime-local"> (sekarang, waktu tempatan)
//   iswLocalInputToIso(v)       → ISO utk psy_payments.paid_at (tarikh & masa bayaran SEBENAR)
//   iswPaidAtProblem(v)         → mesej ralat (BM/EN) kalau tarikh tak sah / masa depan, else null
//   iswUploadPaymentProof(patientId, file) → signed URL (bucket kob-documents) atau null
//   iswRecalcKobPayment(kobId)  → kira semula status bayaran pakej + checkpoint ansuran + buka semula
//                                 tempahan (bila tiada lagi checkpoint tertunggak)
(function () {
  const L = (ms, en) => (window.iswL ? window.iswL(ms, en) : en);

  window.iswNowLocalInput = function () {
    const d = new Date();
    d.setMinutes(d.getMinutes() - d.getTimezoneOffset());
    return d.toISOString().slice(0, 16);
  };

  window.iswLocalInputToIso = function (v) {
    return v ? new Date(v).toISOString() : new Date().toISOString();
  };

  window.iswPaidAtProblem = function (v) {
    if (!v) return L('Sila isi Tarikh & Masa Bayaran.', 'Please enter the payment date & time.');
    const t = new Date(v).getTime();
    if (isNaN(t)) return L('Tarikh & Masa Bayaran tidak sah.', 'Invalid payment date & time.');
    if (t > Date.now() + 5 * 60000) return L('Tarikh & Masa Bayaran tak boleh pada masa hadapan.', 'The payment date & time cannot be in the future.');
    return null;
  };

  window.iswUploadPaymentProof = async function (patientId, file) {
    if (!file) return null;
    const path = `${patientId}/manual/receipt_${Date.now()}_${file.name.replace(/[^a-zA-Z0-9.-]/g, '_')}`;
    const { error } = await window.db.storage.from('kob-documents').upload(path, file);
    if (error) throw error;
    const { data } = await window.db.storage.from('kob-documents').createSignedUrl(path, 3600 * 24 * 365);
    return data?.signedUrl || null;
  };

  window.iswRecalcKobPayment = async function (kobId) {
    const [{ data: kobRows }, { data: cps }, { data: pays }] = await Promise.all([
      window.db.from('psy_kob_sessions').select('patient_id, recommended_package_price, package_payment_mode').eq('id', kobId).limit(1),
      window.db.from('psy_kob_installment_checkpoints').select('id, seq, target_cumulative, status').eq('kob_session_id', kobId).order('seq'),
      window.db.from('psy_payments').select('total').eq('status', 'completed').eq('intent->>kob_session_id', kobId),
    ]);
    const kob = kobRows?.[0];
    if (!kob) return null;
    const totalPaid = (pays || []).reduce((s, p) => s + Number(p.total || 0), 0);
    const isInstallment = kob.package_payment_mode === 'installment' && cps?.length;
    const target = isInstallment ? Number(cps[cps.length - 1].target_cumulative) : Number(kob.recommended_package_price || 0);
    const status = totalPaid <= 0 ? 'pending' : (target > 0 && totalPaid + 0.005 >= target ? 'paid' : 'partial');
    const updates = { package_payment_status: status, updated_at: new Date().toISOString() };
    if (status === 'paid') updates.package_paid_at = new Date().toISOString(); else updates.package_paid_at = null;
    await window.db.from('psy_kob_sessions').update(updates).eq('id', kobId);
    const nowIso = new Date().toISOString();
    for (const cp of (cps || [])) {
      const met = totalPaid + 0.005 >= Number(cp.target_cumulative);
      if (met && cp.status !== 'met') await window.db.from('psy_kob_installment_checkpoints').update({ status: 'met', met_at: nowIso }).eq('id', cp.id);
      else if (!met && cp.status === 'met') await window.db.from('psy_kob_installment_checkpoints').update({ status: 'pending', met_at: null }).eq('id', cp.id);
    }
    // Buka semula tempahan kalau tiada lagi checkpoint tertunggak untuk pesakit ini
    const { data: stillOverdue } = await window.db.from('psy_kob_installment_checkpoints')
      .select('id').eq('patient_id', kob.patient_id).eq('status', 'overdue').limit(1);
    if (!stillOverdue?.length) {
      await window.db.from('psy_patients').update({ booking_blocked: false, booking_blocked_reason: null, booking_blocked_since: null }).eq('id', kob.patient_id);
    }
    return { totalPaid, status };
  };
})();
