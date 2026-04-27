// ============================================================
// PASTE INI DALAM SUPABASE EDGE FUNCTIONS EDITOR
// Function name: invite-staff
// Handles: create | update | delete staff
// ============================================================

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

const ok   = (b: object) => new Response(JSON.stringify(b), { status: 200, headers: { ...cors, 'Content-Type': 'application/json' } })
const fail = (msg: string) => new Response(JSON.stringify({ success: false, error: msg }), { status: 200, headers: { ...cors, 'Content-Type': 'application/json' } })

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors })

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) return fail('Missing authorization header')

    const URL  = Deno.env.get('SUPABASE_URL')!
    const ANON = Deno.env.get('SUPABASE_ANON_KEY')!
    const SVC  = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

    const userClient  = createClient(URL, ANON, { global: { headers: { Authorization: authHeader } } })
    const adminClient = createClient(URL, SVC,  { auth: { autoRefreshToken: false, persistSession: false } })

    // Verify caller
    const { data: { user }, error: authErr } = await userClient.auth.getUser()
    if (authErr || !user) return fail('Tidak sah: sila log masuk semula')

    const { data: profile } = await userClient.from('psy_profiles').select('role, staff_role').eq('id', user.id).single()
    if (!profile || profile.role !== 'staff') return fail('Akses ditolak: bukan staff')
    if (profile.staff_role && profile.staff_role !== 'admin') return fail('Akses ditolak: hanya Admin')

    let body: any
    try { body = await req.json() } catch { return fail('Request body tidak sah') }

    const action = body.action || 'create'

    // ── UPDATE ────────────────────────────────────────────────
    if (action === 'update') {
      const { target_id, full_name, staff_role, specialization, registration_no, phone, is_active } = body
      if (!target_id) return fail('target_id diperlukan')

      const updates: any = {}
      if (full_name      !== undefined) updates.full_name       = full_name
      if (staff_role     !== undefined) updates.staff_role      = staff_role
      if (specialization !== undefined) updates.specialization  = specialization
      if (registration_no!== undefined) updates.registration_no = registration_no
      if (phone          !== undefined) updates.phone           = phone
      if (is_active      !== undefined) updates.is_active       = is_active

      await adminClient.from('psy_profiles').update(updates).eq('id', target_id)

      // Update email/name in auth if name changed
      if (full_name) {
        await adminClient.auth.admin.updateUserById(target_id, {
          user_metadata: { full_name }
        })
      }

      await adminClient.from('psy_audit_log').insert({
        actor_id: user.id, actor_role: 'staff', action: 'staff.updated',
        target: target_id, meta: updates
      }).then(() => {}, () => {})

      return ok({ success: true, message: 'Staff dikemaskini' })
    }

    // ── DELETE ────────────────────────────────────────────────
    if (action === 'delete') {
      const { target_id } = body
      if (!target_id) return fail('target_id diperlukan')
      if (target_id === user.id) return fail('Tidak boleh padam akaun sendiri')

      // Cek target — admin tidak boleh dipadam
      const { data: targetProfile } = await adminClient
        .from('psy_profiles')
        .select('staff_role')
        .eq('id', target_id)
        .single()
      if (targetProfile?.staff_role === 'admin') return fail('Akaun Admin tidak boleh dipadam')

      // Bersihkan SEMUA FK references supaya delete tak fail
      await Promise.allSettled([
        adminClient.from('psy_appointments').update({ staff_id: null }).eq('staff_id', target_id),
        adminClient.from('psy_treatment_plans').update({ doctor_id: null }).eq('doctor_id', target_id),
        adminClient.from('psy_kyc_submissions').update({ reviewed_by: null }).eq('reviewed_by', target_id),
        adminClient.from('psy_plan_weekly_progress').update({ updated_by: null }).eq('updated_by', target_id),
        adminClient.from('psy_patients').update({ coach_id: null }).eq('coach_id', target_id),
        adminClient.from('psy_vitals').update({ recorded_by: null }).eq('recorded_by', target_id),
        adminClient.from('psy_coaching_sessions').update({ coach_id: null }).eq('coach_id', target_id),
        adminClient.from('psy_risk_alerts').update({ created_by: null }).eq('created_by', target_id),
        adminClient.from('psy_risk_alerts').update({ acknowledged_by: null }).eq('acknowledged_by', target_id),
        adminClient.from('psy_payments').update({ user_id: null }).eq('user_id', target_id),
      ])

      // Delete profile dulu (kerana psy_patients.user_id → psy_profiles tanpa cascade)
      await adminClient.from('psy_patients').delete().eq('user_id', target_id)
      await adminClient.from('psy_kyc_submissions').delete().eq('user_id', target_id)
      await adminClient.from('psy_profiles').delete().eq('id', target_id)

      // Delete auth user
      const { error: delErr } = await adminClient.auth.admin.deleteUser(target_id)
      if (delErr) return fail(delErr.message)

      await adminClient.from('psy_audit_log').insert({
        actor_id: user.id, actor_role: 'staff', action: 'staff.deleted',
        target: target_id, meta: {}
      }).then(() => {}, () => {})

      return ok({ success: true, message: 'Akaun staff dipadam' })
    }

    // ── CREATE ────────────────────────────────────────────────
    if (!body.email || !body.full_name) return fail('Email dan nama wajib diisi')
    if (!['admin','doctor','coach','manager'].includes(body.staff_role)) return fail('Staff role tidak sah')

    let newUserId: string

    if (body.send_invite !== false) {
      const { data, error } = await adminClient.auth.admin.inviteUserByEmail(body.email, {
        data: { full_name: body.full_name, role: 'staff', staff_role: body.staff_role }
      })
      if (error) return fail(error.message)
      newUserId = data.user.id
    } else {
      if (!body.temp_password || body.temp_password.length < 6) return fail('Password min 6 aksara')
      const { data, error } = await adminClient.auth.admin.createUser({
        email: body.email, password: body.temp_password, email_confirm: true,
        user_metadata: { full_name: body.full_name, role: 'staff', staff_role: body.staff_role }
      })
      if (error) return fail(error.message)
      newUserId = data.user.id
    }

    await new Promise(r => setTimeout(r, 600))
    await adminClient.from('psy_profiles').update({
      staff_role: body.staff_role,
      specialization:   body.specialization   || null,
      registration_no:  body.registration_no  || null,
      phone:            body.phone            || null,
    }).eq('id', newUserId)

    const { data: callerName } = await userClient.from('psy_profiles').select('full_name').eq('id', user.id).single()
    await adminClient.from('psy_audit_log').insert({
      actor_id: user.id, actor_name: callerName?.full_name, actor_role: 'staff',
      action: 'staff.invited', target: newUserId,
      meta: { email: body.email, name: body.full_name, staff_role: body.staff_role }
    }).then(() => {}, () => {})

    return ok({ success: true, user_id: newUserId,
      message: body.send_invite !== false ? 'Email invite dihantar' : 'Akaun dicipta dengan password sementara'
    })

  } catch (err: any) {
    console.error('invite-staff error:', err)
    return fail(err?.message || 'Ralat tidak diketahui')
  }
})
