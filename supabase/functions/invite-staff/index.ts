// ============================================================
// Edge Function: invite-staff
// Urus akaun staff (cipta/kemaskini/nyahaktifkan) oleh admin (yang sudah login sebagai staff)
// ============================================================

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// Diletak terus dalam fail ni (bukan import '../_shared/cors.ts') sebab
// deploy manual via Supabase Dashboard (paste code editor) tak bundle fail
// luar — cuma index.ts dalam function ni sahaja yang di-deploy.
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

interface StaffRequest {
  action?: 'invite' | 'update' | 'delete'; // tiada action = 'invite' (backward-compat form lama)
  target_id?: string;   // wajib untuk 'update' & 'delete'
  email?: string;
  full_name?: string;
  staff_role?: string;
  specialization?: string;
  registration_no?: string;
  phone?: string;
  is_active?: boolean;
  send_invite?: boolean; // true = email invite, false = create with temp password
  temp_password?: string;
}

const PERMANENT_BAN = '876000h' // ~100 tahun — cara Supabase sekat login kekal

Deno.serve(async (req: Request) => {
  // CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Verify caller is authenticated and is staff
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) throw new Error('Missing authorization')

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

    // Use anon key + caller's JWT to verify they're a staff
    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } }
    })
    const { data: { user }, error: userErr } = await userClient.auth.getUser()
    if (userErr || !user) throw new Error('Tidak sah: sila log masuk semula')

    // PENTING: select KEDUA-DUA 'role' DAN 'staff_role' — select('role') sahaja
    // punca gate kebenaran di bawah sentiasa gagal (staff_role jadi undefined)
    // walaupun caller sebenarnya admin/manager/super_admin.
    const { data: callerProfile } = await userClient
      .from('psy_profiles')
      .select('role, staff_role')
      .eq('id', user.id)
      .single()

    if (!callerProfile || callerProfile.role !== 'staff') {
      throw new Error('Akses ditolak: hanya staff boleh urus akaun staff')
    }
    const ALLOWED_ROLES = ['admin', 'manager', 'super_admin']
    if (!ALLOWED_ROLES.includes(callerProfile.staff_role)) {
      throw new Error('Akses ditolak: hanya Admin, Manager, atau Super Admin boleh urus akaun staff')
    }

    const body: StaffRequest = await req.json()
    const action = body.action || 'invite'

    // Use service role key for admin operations
    const adminClient = createClient(supabaseUrl, serviceKey, {
      auth: { autoRefreshToken: false, persistSession: false }
    })

    const callerName = (await userClient.from('psy_profiles').select('full_name').eq('id', user.id).single()).data?.full_name

    // ──────────────────────────────────────────────────────
    // ACTION: update — kemaskini profil staff sedia ada
    // ──────────────────────────────────────────────────────
    if (action === 'update') {
      if (!body.target_id) throw new Error('target_id wajib')

      if (body.staff_role) {
        const { data: roleRow } = await userClient.from('psy_roles')
          .select('code').eq('code', body.staff_role).eq('is_active', true).maybeSingle()
        if (!roleRow) throw new Error(`Staff role '${body.staff_role}' tidak sah atau tidak aktif`)
      }

      const patch: Record<string, unknown> = {}
      if (body.full_name !== undefined)       patch.full_name = body.full_name
      if (body.staff_role !== undefined)      patch.staff_role = body.staff_role
      if (body.registration_no !== undefined) patch.registration_no = body.registration_no
      if (body.phone !== undefined)           patch.phone = body.phone
      if (body.specialization !== undefined)  patch.specialization = body.specialization
      if (body.is_active !== undefined)       patch.is_active = body.is_active

      const { error: updErr } = await adminClient.from('psy_profiles').update(patch).eq('id', body.target_id)
      if (updErr) throw updErr

      // is_active togol dari form edit — selaraskan sekatan log masuk di peringkat auth jugak.
      if (body.is_active !== undefined) {
        await adminClient.auth.admin.updateUserById(body.target_id, {
          ban_duration: body.is_active ? 'none' : PERMANENT_BAN,
        })
      }

      await adminClient.from('psy_audit_log').insert({
        actor_id: user.id, actor_name: callerName, actor_role: 'staff',
        action: 'staff.updated', target: body.target_id, meta: patch,
      })

      return new Response(
        JSON.stringify({ success: true, message: 'Staff berjaya dikemaskini' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // ──────────────────────────────────────────────────────
    // ACTION: delete — NYAHAKTIFKAN sahaja (bukan padam terus), supaya
    // rekod sejarah (sesi, audit, payout dll) kekal utuh. Sekat log masuk
    // di peringkat auth (ban) + tanda is_active=false pada profil.
    // ──────────────────────────────────────────────────────
    if (action === 'delete') {
      if (!body.target_id) throw new Error('target_id wajib')

      const { error: banErr } = await adminClient.auth.admin.updateUserById(body.target_id, {
        ban_duration: PERMANENT_BAN,
      })
      if (banErr) throw banErr

      const { error: updErr } = await adminClient.from('psy_profiles')
        .update({ is_active: false }).eq('id', body.target_id)
      if (updErr) throw updErr

      await adminClient.from('psy_audit_log').insert({
        actor_id: user.id, actor_name: callerName, actor_role: 'staff',
        action: 'staff.deactivated', target: body.target_id, meta: {},
      })

      return new Response(
        JSON.stringify({ success: true, message: 'Akaun staff dinyahaktifkan' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // ──────────────────────────────────────────────────────
    // ACTION: invite (default) — cipta staff baru
    // ──────────────────────────────────────────────────────
    if (!body.email || !body.full_name) {
      throw new Error('Email dan nama wajib diisi')
    }
    // Semak terus dari psy_roles (bukan senarai hardcode) — supaya role custom
    // ciptaan peranan.html (cth. 'kob') turut boleh diguna di sini, sepadan dgn
    // dropdown "Pilih Role" di staff_management.html yg dah tarik dinamik dari
    // psy_roles. Senarai hardcode lama ('telesale') tak sepadan dgn role sebenar
    // yg wujud (cth. 'kob'/'telesales'), punca staff baharu gagal dijemput ke role tu.
    const { data: roleRow } = await userClient.from('psy_roles')
      .select('code').eq('code', body.staff_role).eq('is_active', true).maybeSingle()
    if (!roleRow) {
      throw new Error(`Staff role '${body.staff_role}' tidak sah atau tidak aktif`)
    }

    let newUserId: string

    if (body.send_invite !== false) {
      // Send email invite — user sets own password via email link
      const { data, error } = await adminClient.auth.admin.inviteUserByEmail(body.email, {
        data: { full_name: body.full_name, role: 'staff' },
      })
      if (error) throw error
      newUserId = data.user.id
    } else {
      // Create with temp password (admin-set)
      if (!body.temp_password || body.temp_password.length < 6) {
        throw new Error('Temp password mestilah min 6 aksara')
      }
      const { data, error } = await adminClient.auth.admin.createUser({
        email: body.email,
        password: body.temp_password,
        email_confirm: true,
        user_metadata: { full_name: body.full_name, role: 'staff' },
      })
      if (error) throw error
      newUserId = data.user.id
    }

    // Update profile with staff_role and extra info
    await new Promise(r => setTimeout(r, 500))
    await adminClient
      .from('psy_profiles')
      .update({
        staff_role: body.staff_role,
        specialization: body.specialization || null,
        registration_no: body.registration_no || null,
        phone: body.phone || null,
      })
      .eq('id', newUserId)

    // Audit log
    await adminClient.from('psy_audit_log').insert({
      actor_id: user.id,
      actor_name: callerName,
      actor_role: 'staff',
      action: 'staff.invited',
      target: newUserId,
      meta: { email: body.email, name: body.full_name, staff_role: body.staff_role, send_invite: body.send_invite !== false },
    })

    return new Response(
      JSON.stringify({ success: true, user_id: newUserId, message: body.send_invite !== false ? 'Email invite dihantar' : 'Akaun dicipta dengan password sementara' }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (err) {
    console.error(err)
    return new Response(
      JSON.stringify({ error: err.message }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
