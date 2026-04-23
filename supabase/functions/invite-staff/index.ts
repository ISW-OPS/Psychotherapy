// ============================================================
// Edge Function: invite-staff
// Cipta akaun staff baru oleh admin (yang sudah login sebagai staff)
// ============================================================

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'

interface InviteRequest {
  email: string;
  full_name: string;
  staff_role: 'admin' | 'doctor' | 'coach' | 'manager';
  specialization?: string;
  registration_no?: string;
  phone?: string;
  send_invite?: boolean; // true = email invite, false = create with temp password
  temp_password?: string;
}

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

    const { data: callerProfile } = await userClient
      .from('psy_profiles')
      .select('role')
      .eq('id', user.id)
      .single()

    if (!callerProfile || callerProfile.role !== 'staff') {
      throw new Error('Akses ditolak: hanya staff boleh daftar staff baru')
    }
    if (callerProfile.staff_role !== 'admin') {
      throw new Error('Akses ditolak: hanya Admin boleh daftar staff baru')
    }

    // Parse request body
    const body: InviteRequest = await req.json()
    if (!body.email || !body.full_name) {
      throw new Error('Email dan nama wajib diisi')
    }
    if (!['admin', 'doctor', 'coach', 'manager'].includes(body.staff_role)) {
      throw new Error('Staff role mesti admin, doctor, coach, atau manager')
    }

    // Use service role key for admin operations
    const adminClient = createClient(supabaseUrl, serviceKey, {
      auth: { autoRefreshToken: false, persistSession: false }
    })

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
      actor_name: (await userClient.from('psy_profiles').select('full_name').eq('id', user.id).single()).data?.full_name,
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
