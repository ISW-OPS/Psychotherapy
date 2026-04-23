async function checkAuth(requiredRole) {
  const { data: { session } } = await window.db.auth.getSession();

  if (!session) {
    window.location.href = '../../auth/login.html';
    return null;
  }

  const { data: profile } = await window.db
    .from('psy_profiles')
    .select('*')
    .eq('id', session.user.id)
    .single();

  if (!profile || profile.role !== requiredRole) {
    await window.db.auth.signOut();
    localStorage.removeItem('isw_role');
    localStorage.removeItem('isw_name');
    alert('Akses tidak dibenarkan');
    window.location.href = '../../auth/login.html';
    return null;
  }

  localStorage.setItem('isw_role', profile.role);
  localStorage.setItem('isw_name', profile.full_name);

  return { ...session.user, ...profile };
}

function getBasePath() {
  return '../../';
}
