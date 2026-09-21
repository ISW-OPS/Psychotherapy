// ── Rekod / amaran "Tidak Hadir > 7 hari" ──────────────────────────────────────
// Dipanggil sebaik sesi ditanda Tidak Hadir (Appointments, Dashboard). Kalau pesakit sudah lebih 7 hari
// tanpa kehadiran (sejak sesi 'hadir' terakhir, atau sejak pelan bermula kalau belum pernah hadir):
//   • catat audit log 'plan.absent_over_7d' (rekod kekal, boleh diaudit)
//   • hantar notifikasi kepada coach pesakit (psy_notifications)
// Dedup: tak cetus lagi kalau pesakit ini sudah dibenderakan dalam 7 hari lepas.
//   iswFlagLongAbsence({ patientId, sessionId }) → { flagged: bool, days } (tak pernah melempar ralat)
(function () {
  const L = (ms, en) => (window.iswL ? window.iswL(ms, en) : ms);

  window.iswFlagLongAbsence = async function ({ patientId, sessionId }) {
    try {
      if (!patientId || !window.db) return { flagged: false, days: null };
      const [{ data: lastHadir }, { data: pt }] = await Promise.all([
        window.db.from('psy_plan_weekly_progress').select('session_date')
          .eq('patient_id', patientId).eq('status', 'hadir').order('session_date', { ascending: false }).limit(1),
        window.db.from('psy_patients').select('full_name, coach_id, psy_profiles!psy_patients_user_id_fkey(full_name)').eq('id', patientId).maybeSingle(),
      ]);
      let since = lastHadir?.[0]?.session_date || null;
      if (!since) {
        const { data: plan } = await window.db.from('psy_treatment_plans').select('start_date, created_at')
          .eq('patient_id', patientId).eq('status', 'active').order('created_at', { ascending: false }).limit(1);
        since = plan?.[0]?.start_date || plan?.[0]?.created_at || null;
      }
      if (!since) return { flagged: false, days: null };
      const days = Math.floor((Date.now() - new Date(since).getTime()) / 86400000);
      if (days <= 7) return { flagged: false, days };

      // Dedup 7 hari
      const cutoff = new Date(Date.now() - 7 * 86400000).toISOString();
      const { data: recent } = await window.db.from('psy_audit_log').select('id')
        .eq('action', 'plan.absent_over_7d').eq('target', patientId).gte('created_at', cutoff).limit(1);
      if (recent?.length) return { flagged: false, days, duplicate: true };

      if (typeof auditLog === 'function') {
        try { await auditLog('plan.absent_over_7d', patientId, { days, session_id: sessionId || null, since }); } catch (_) { }
      }
      if (pt?.coach_id) {
        const name = pt.psy_profiles?.full_name || pt.full_name || L('Pesakit', 'Patient');
        try {
          await window.db.from('psy_notifications').insert({
            user_id: pt.coach_id, type: 'system',
            title: L('🚨 Pesakit tidak hadir lebih 7 hari', '🚨 Patient absent for more than 7 days'),
            body: L(`${name} — ${days} hari sejak kehadiran terakhir. Sila hubungi pesakit.`, `${name} — ${days} days since the last attendance. Please contact the patient.`),
            link: 'appointments.html',
          });
        } catch (_) { }
      }
      return { flagged: true, days };
    } catch (_) {
      return { flagged: false, days: null };
    }
  };
})();
