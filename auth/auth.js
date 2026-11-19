async function resolvePatientDest(userId) {
  const { data: patient } = await window.db
    .from('psy_patients').select('kob_status').eq('user_id', userId).maybeSingle();
  const ks = patient?.kob_status;
  let dest = '/roles/patient/dashboard.html';
  if (!patient || ks === 'paid' || ks === 'pending_payment') {
    const { data: kyc } = await window.db
      .from('psy_kyc_submissions').select('id, status').eq('user_id', userId)
      .order('created_at', { ascending: false }).limit(1);
    const kycOk = kyc?.length && kyc[0].status !== 'rejected';
    dest = kycOk ? '/roles/patient/kob.html' : '/roles/patient/pendaftaran.html';
  } else if (['kyc_done', 'hadir', 'package_recommended', 'package_paid'].includes(ks)) {
    dest = '/roles/patient/kob.html';
  }
  return dest;
}

async function handleLogin(e) {
  if (e) e.preventDefault();
  const email = document.getElementById('login-email').value.trim();
  const password = document.getElementById('login-password').value;
  const errEl = document.getElementById('login-error');
  errEl.classList.add('hidden');

  if (!email || !password) {
    errEl.textContent = 'Email dan kata laluan wajib diisi';
    errEl.classList.remove('hidden');
    return;
  }

  const btn = document.getElementById('login-btn');
  btn.disabled = true;
  btn.textContent = 'Sedang log masuk...';

  if (!window.db) {
    errEl.textContent = 'Sambungan gagal. Sila muat semula halaman (F5) dan cuba lagi.';
    errEl.classList.remove('hidden');
    btn.disabled = false;
    btn.textContent = 'Log Masuk';
    return;
  }

  try {
    const { data, error } = await window.db.auth.signInWithPassword({ email, password });
    if (error) throw error;

    const { data: profile } = await window.db
      .from('psy_profiles')
      .select('role, full_name')
      .eq('id', data.user.id)
      .maybeSingle();

    if (!profile) {
      errEl.textContent = 'Profil tidak dijumpai. Sila hubungi admin atau daftar semula.';
      errEl.classList.remove('hidden');
      await window.db.auth.signOut();
      btn.disabled = false;
      btn.textContent = 'Log Masuk';
      return;
    }

    localStorage.setItem('isw_role', profile.role);
    localStorage.setItem('isw_name', profile.full_name);

    window.db.from('psy_audit_log').insert({
      actor_id: data.user.id,
      actor_name: profile.full_name,
      actor_role: profile.role,
      action: 'auth.login',
      meta: { user_agent: navigator.userAgent }
    }).then(() => {}, () => {});

    if (profile.role === 'patient') {
      const dest = await resolvePatientDest(data.user.id);
      await window.iswGoToRolePage('patient', dest);
    } else {
      await window.iswGoToRolePage(profile.role, `/roles/${profile.role}/dashboard.html`);
    }
  } catch (err) {
    errEl.textContent = err.message === 'Invalid login credentials'
      ? 'Email atau kata laluan salah'
      : err.message;
    errEl.classList.remove('hidden');
    btn.disabled = false;
    btn.textContent = 'Log Masuk';
  }
}

async function handleForgot(e) {
  if (e) e.preventDefault();
  const email = document.getElementById('forgot-email').value.trim();
  const errEl = document.getElementById('forgot-error');
  const okEl = document.getElementById('forgot-success');
  errEl.classList.add('hidden');
  okEl.classList.add('hidden');

  if (!email) {
    errEl.textContent = 'Sila masukkan email';
    errEl.classList.remove('hidden');
    return;
  }

  const btn = document.getElementById('forgot-btn');
  btn.disabled = true;
  btn.textContent = 'Menghantar...';

  try {
    const redirectTo = `${window.location.origin}${window.location.pathname.replace('login.html','reset.html')}`;
    const { error } = await window.db.auth.resetPasswordForEmail(email, { redirectTo });
    if (error) throw error;

    okEl.textContent = 'Link reset telah dihantar ke ' + email + '. Sila check inbox/spam.';
    okEl.classList.remove('hidden');
    btn.textContent = 'Hantar Link Reset';
    btn.disabled = false;
  } catch (err) {
    errEl.textContent = err.message;
    errEl.classList.remove('hidden');
    btn.disabled = false;
    btn.textContent = 'Hantar Link Reset';
  }
}

async function handleSignup(e) {
  if (e) e.preventDefault();
  const name = document.getElementById('signup-name').value.trim();
  const email = document.getElementById('signup-email').value.trim();
  const password = document.getElementById('signup-password').value;
  const role = document.getElementById('signup-role')?.value || 'patient';
  const errEl = document.getElementById('signup-error');
  errEl.classList.add('hidden');

  if (!name || !email || !password) {
    errEl.textContent = 'Semua ruangan wajib diisi';
    errEl.classList.remove('hidden');
    return;
  }

  if (password.length < 6) {
    errEl.textContent = 'Kata laluan mestilah sekurang-kurangnya 6 aksara';
    errEl.classList.remove('hidden');
    return;
  }

  const btn = document.getElementById('signup-btn');
  btn.disabled = true;
  btn.textContent = 'Mendaftar...';

  try {
    const { data, error } = await window.db.auth.signUp({
      email,
      password,
      options: {
        data: { full_name: name, role }
      }
    });
    if (error) throw error;

    document.getElementById('signup-form').classList.add('hidden');
    document.getElementById('otp-email').value = email;
    document.getElementById('otp-email-display').textContent = email;
    document.getElementById('otp-code').value = '';
    document.getElementById('otp-form').classList.remove('hidden');
    btn.disabled = false;
    btn.textContent = 'Daftar Akaun';
  } catch (err) {
    const msg = err.message || '';
    let userMsg = msg;
    if (msg.toLowerCase().includes('already registered') || msg.toLowerCase().includes('already exists')) {
      userMsg = 'Email ini sudah didaftarkan. Sila log masuk atau guna email lain.';
    } else if (msg.toLowerCase().includes('invalid email')) {
      userMsg = 'Format email tidak sah';
    } else if (msg.toLowerCase().includes('rate limit')) {
      userMsg = 'Terlalu banyak percubaan. Tunggu sebentar dan cuba lagi.';
    } else if (msg.toLowerCase().includes('password')) {
      userMsg = 'Kata laluan terlalu lemah atau pendek';
    }
    errEl.textContent = userMsg;
    errEl.classList.remove('hidden');
    btn.disabled = false;
    btn.textContent = 'Daftar Akaun';
  }
}

async function handleVerifyOtp(e) {
  if (e) e.preventDefault();
  const email = document.getElementById('otp-email').value;
  const token = document.getElementById('otp-code').value.trim();
  const errEl = document.getElementById('otp-error');
  errEl.classList.add('hidden');

  if (!/^\d{6,8}$/.test(token)) {
    errEl.textContent = 'Sila masukkan kod yang dihantar ke email anda';
    errEl.classList.remove('hidden');
    return;
  }

  const btn = document.getElementById('otp-btn');
  btn.disabled = true;
  btn.textContent = 'Mengesahkan...';

  try {
    const { data, error } = await window.db.auth.verifyOtp({ email, token, type: 'signup' });
    if (error) throw error;

    const { data: profile } = await window.db
      .from('psy_profiles')
      .select('role, full_name')
      .eq('id', data.user.id)
      .maybeSingle();

    const role = profile?.role || 'patient';
    localStorage.setItem('isw_role', role);
    localStorage.setItem('isw_name', profile?.full_name || '');

    window.db.from('psy_audit_log').insert({
      actor_id: data.user.id,
      actor_name: profile?.full_name,
      actor_role: role,
      action: 'auth.signup_verified',
      meta: { user_agent: navigator.userAgent }
    }).then(() => {}, () => {});

    const dest = role === 'patient' ? await resolvePatientDest(data.user.id) : `/roles/${role}/dashboard.html`;
    await window.iswGoToRolePage(role, dest);
  } catch (err) {
    const msg = err.message || '';
    errEl.textContent = msg.toLowerCase().includes('expired')
      ? 'Kod telah tamat tempoh. Sila hantar semula kod.'
      : msg.toLowerCase().includes('invalid') || msg.toLowerCase().includes('token')
        ? 'Kod tidak sah. Sila semak dan cuba lagi.'
        : msg;
    errEl.classList.remove('hidden');
    btn.disabled = false;
    btn.textContent = 'Sahkan Kod';
  }
}

async function handleResendOtp() {
  const email = document.getElementById('otp-email').value;
  const errEl = document.getElementById('otp-error');
  const resendBtn = document.getElementById('otp-resend-btn');
  errEl.classList.add('hidden');
  resendBtn.disabled = true;
  const originalText = resendBtn.textContent;

  try {
    const { error } = await window.db.auth.resend({ type: 'signup', email });
    if (error) throw error;
    resendBtn.textContent = 'Kod baharu dihantar!';
    setTimeout(() => {
      resendBtn.disabled = false;
      resendBtn.textContent = originalText;
    }, 30000);
  } catch (err) {
    errEl.textContent = err.message;
    errEl.classList.remove('hidden');
    resendBtn.disabled = false;
  }
}
