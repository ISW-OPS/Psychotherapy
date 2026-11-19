async function logout() {
  await window.db.auth.signOut();
  localStorage.removeItem('isw_role');
  localStorage.removeItem('isw_name');
  if (window.iswGoToLogin) window.iswGoToLogin('/auth/login.html');
  else window.location.href = '../../auth/login.html';
}
