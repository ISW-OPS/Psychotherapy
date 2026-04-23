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

    window.location.href = `../roles/${profile.role}/dashboard.html`;
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

    document.getElementById('signup-success').classList.remove('hidden');
    document.getElementById('signup-form').classList.add('hidden');
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
