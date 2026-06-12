# ISW WhatsApp Inbox — Pelan Teknikal (MVP)

> Matlamat: coach guna **satu sistem (ISW) sahaja** untuk balas WhatsApp pesakit.
> GHL kekal hidup di belakang (pegang nombor WhatsApp + sales team). ISW jadi muka depan.
> Keputusan skop MVP: **tarik SEMUA perbualan aktif dulu** (kedua-dua nombor),
> tapis "Pesakit saya" kemudian (peringkat +1).

Project ref Supabase: `ipmemyizigwgivccytcu`
Deploy guna: `npx supabase functions deploy <name> --project-ref ipmemyizigwgivccytcu`

---

## Senibina

```
                         ┌─────────── GHL (LeadConnector) ───────────┐
Pesakit ─WhatsApp─► Nombor GHL ──► GHL Conversations  ◄── sales team │
                         └───────────────┬───────────────────────────┘
                                         │ GHL API v2
                  ┌──────────────────────┴───────────────────────┐
                  ▼ (baca senarai + mesej)        ▲ (hantar mesej) │
        Edge Function: ghl-inbox-fetch    Edge Function: ghl-inbox-send
                  │                                ▲
                  ▼ cache                          │
            Supabase (jadual cache)                │
                  │                                │
                  ▼ window.db (realtime/select)    │ fetch()
        roles/staff/inbox.html  ───────────────────┘
        (coach baca + balas dalam ISW)
```

MVP guna **refresh manual** (poll). Realtime (webhook GHL) = peringkat +2.

---

## Komponen

### 1. Jadual Supabase (cache) — migration `stepXX_whatsapp_inbox.sql`

**`psy_wa_conversations`** — satu baris per perbualan GHL
| kolum | jenis | nota |
|---|---|---|
| `id` | uuid PK default gen_random_uuid() | |
| `ghl_conversation_id` | text UNIQUE | id perbualan GHL |
| `ghl_contact_id` | text | |
| `contact_name` | text | |
| `phone_e164` | text | join key ke psy_patients nanti |
| `wa_number` | text | nombor mana mesej masuk (+60389663702 / +60360430663) |
| `last_message` | text | preview |
| `last_message_at` | timestamptz | untuk susun |
| `unread` | int default 0 | |
| `patient_id` | uuid NULL refs psy_patients(id) | diisi bila phone padan (peringkat +1) |
| `synced_at` | timestamptz default now() | |

**`psy_wa_messages`** — satu baris per mesej
| kolum | jenis | nota |
|---|---|---|
| `id` | uuid PK | |
| `ghl_message_id` | text UNIQUE | elak duplicate |
| `ghl_conversation_id` | text | FK logikal |
| `direction` | text | 'inbound' / 'outbound' |
| `body` | text | |
| `msg_type` | text | 'whatsapp' (MVP teks) |
| `sent_by` | text NULL | staff_id ISW kalau dihantar dari ISW |
| `created_at` | timestamptz | masa mesej GHL |

RLS: benarkan SELECT untuk staff yang authenticated (ikut corak page staff lain).
INSERT/UPDATE hanya via Edge Function (service role) — bukan client.

### 2. Edge Function `ghl-inbox-fetch` (GET — tarik dari GHL → cache)
- Auth: JWT staff (verify caller staff) ATAU panggil dari page dengan anon + RLS. Pilih: verify-jwt ON, semak role staff.
- Langkah:
  1. `GET {GHL_BASE}/conversations/search?locationId=...&sort=desc&sortBy=last_message_date&limit=50`
     → senarai perbualan aktif terkini (MVP: 50 terbaru, bukan semua sejarah).
  2. Upsert setiap satu ke `psy_wa_conversations` (by `ghl_conversation_id`).
  3. (Optional pada buka perbualan) `GET /conversations/{id}/messages?limit=50`
     → upsert ke `psy_wa_messages`.
- Pulang: senarai conversations terkini.

### 3. Edge Function `ghl-inbox-send` (POST — hantar via GHL)
- Body: `{ ghl_contact_id, message }`
- `POST {GHL_BASE}/conversations/messages`
  body `{ type: "WhatsApp", contactId, message }`
- Selepas berjaya: insert ke `psy_wa_messages` (direction outbound, sent_by = staff id).
- Header GHL: `Authorization: Bearer GHL_ISW_TOKEN`, `Version: 2021-07-28`.

> Guna semula corak `ghl()` helper + `toE164()` yang dah ada dalam `sync-ghl/index.ts`.

### 4. Halaman `roles/staff/inbox.html`
- Pola sama macam `announcements.html`: `app-loading` → `app-shell`, `initStaff('inbox', ...)`.
- Layout 2-panel: kiri senarai perbualan, kanan tetingkap chat + kotak taip.
- Butang "Muat semula" (panggil `ghl-inbox-fetch`).
- Hantar → `ghl-inbox-send` → tambah bubble + reload mesej.
- Guna `window.db` untuk baca cache (`psy_wa_conversations`, `psy_wa_messages`).

### 5. Navbar — tambah item dalam `shared/navbar.js`
- Dalam `STAFF_NAV_MASTER` group **KOMUNIKASI**:
  `{ id: 'inbox', url: 'inbox.html', icon: '💬', label: 'WhatsApp' }`
- Tambah `'inbox'` ke `STAFF_ROLE_ACCESS` (admin/coach/manager/doctor) dalam `roles/staff/_shared.js`.
- (RBAC: tambah mapping dalam `PAGE_MODULE` kalau perlu modul baru, atau guna sedia ada.)

---

## Yang ANDA perlu sediakan di GHL

1. **Tambah scope pada token GHL ISW** (`GHL_ISW_TOKEN`, Private Integration):
   - `conversations.readonly`
   - `conversations.write`
   - `conversations/message.readonly`
   - `conversations/message.write`
2. Sahkan `GHL_ISW_LOCATION_ID` = `cVOgqxddpXRzqaIXFkxl` (dah ada sebagai secret).
3. (Peringkat +2 sahaja) Pasang webhook GHL `InboundMessage` → `ghl-inbox-webhook`.

Secrets sedia ada (`GHL_ISW_TOKEN`, `GHL_ISW_LOCATION_ID`) — guna semula, JANGAN timpa.

---

## Peringkat (berperingkat, buktikan dulu)

| Peringkat | Skop | Hasil |
|---|---|---|
| **MVP** | fetch 50 perbualan terkini + baca + hantar teks + refresh manual | Coach balas WhatsApp dari ISW |
| **+1** | tapis "Pesakit saya" (padan phone ↔ psy_patients), tab Semua/Pesakit | Inbox bersih |
| **+2** | webhook GHL → realtime, badge unread di navbar | Mesej masuk auto |
| **+3** | media (gambar/audio/PDF), carian, assign | Penuh |

---

## Risiko / had

- Bergantung GHL aktif (nombor WhatsApp di GHL). GHL mati → WhatsApp putus.
- MVP tarik 50 terkini sahaja — sejarah lama tak ditarik (elak backfill berat). Dilog.
- Balas dari ISW & GHL kedua-dua nampak (sinkron sebab GHL pegang nombor) — bagus.
- GHL API rate limit — poll jangan terlalu kerap (cadang manual / 30s).

---

## Urutan kerja bila mula

1. Migration jadual cache (anda jalankan SQL di Supabase).
2. Edge Function `ghl-inbox-fetch` + `ghl-inbox-send` (deploy).
3. `inbox.html` + nav item + RBAC.
4. Uji hujung-ke-hujung dengan satu perbualan sebenar.
</content>
</invoke>
