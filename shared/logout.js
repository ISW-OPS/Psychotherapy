async function logout() {
  await window.db.auth.signOut();
  localStorage.removeItem('isw_role');
  localStorage.removeItem('isw_name');
  window.location.href = '../../auth/login.html';
}
