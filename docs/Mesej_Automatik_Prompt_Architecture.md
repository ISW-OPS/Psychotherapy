# Prompt — Jana Rajah Flow / Architecture (GPT / Claude)

Salin **seluruh blok** di bawah dan tampal ke GPT atau Claude. Ia akan hasilkan
rajah Mermaid (flowchart + sequence) untuk modul Mesej Automatik ISW.

---

```
You are a software architect. Produce clear architecture & flow diagrams (Mermaid syntax)
for the "Automated Messaging" (Mesej Automatik) module of the ISW (Ibnu Sina Wellness)
psychotherapy admin system. Output: (A) a component/architecture diagram, (B) an
end-to-end sequence diagram, and (C) a short legend. Use Mermaid so I can render it.

CONTEXT — TECH STACK
- Frontend: static HTML + inline JS + Tailwind, talking directly to Supabase (client-side).
- Backend: Supabase Postgres + Row Level Security; one Deno Edge Function as the engine.
- Messaging: GoHighLevel (GHL) API for WhatsApp & Email. In-App = rows in a notifications table.
- Scheduler: a cron job hits the Edge Function every 15 minutes.

DATABASE TABLES
- psy_automations       : automation definitions (trigger_category, trigger_event,
                          trigger_timing[jsonb schedule/before/after], conditions[jsonb],
                          conditions_enabled, actions[whatsapp|inapp|email], message_template,
                          status[draft|active|paused], last_run_at).
- psy_notification_logs : one row per send attempt (status sent|failed|pending, channel,
                          patient_id, automation_id, message, error, created_at).
- psy_audiences         : saved, named targeting criteria (conditions jsonb), reusable.
- psy_auto_messages     : reusable message templates + system messages (category, language,
                          tags, message_template, trigger_type).
- psy_patients, psy_packages, psy_profiles, psy_treatment_plans : data sources for variables.

ENGINE (Edge Function: event-reminders)
- Triggered by cron every 15 min.
- runScheduledAutomations(): reads active automations with schedule trigger, checks day/time,
  dedupes once/day via last_run_at.
- applyConds(): filters patients by conditions (patient_status, gender, package, state, age,
  registered date). Conditions may come from an inline set OR a saved psy_audiences record.
- buildPatientVars(): fills message variables ({{nama}}, {{pakej}}, {{minggu}}, {{coach}},
  {{tarikh}}, {{telefon_klinik}}, etc.) from patient + package + coach + treatment plan +
  clinic constants + system date.
- Sends via GHL (WhatsApp/Email) or inserts In-App notification, then writes psy_notification_logs.

UI PAGES (staff)
- Dashboard, Senarai Automasi (list), Cipta/Edit Automasi (5-step builder),
  Template Mesej (gallery), Template Builder (editor), Variables Library, Audience builder,
  Queue/Scheduled, Log Penghantaran (logs), Butiran Automasi (detail), Test Automation.

ACTORS
- Staff (admin/coach) using the UI.
- Cron scheduler.
- Edge Function engine.
- GHL (external messaging).
- Patient (recipient).

KEY FLOWS TO SHOW
1. Staff creates/edits an automation in the Builder → saved to psy_automations.
2. Staff optionally creates an Audience (psy_audiences) reused by automations.
3. Staff creates message Templates (psy_auto_messages) with variables.
4. Cron → engine → applyConds (patients/audience) → buildPatientVars → GHL/In-App → logs.
5. Staff sends a manual Test (Test Automation page) → GHL/In-App directly, not counted in stats.
6. Staff monitors results via Dashboard / Logs / Detail (reads psy_notification_logs).

HONESTY CONSTRAINTS (reflect as notes on the diagram)
- Read receipts & responses are NOT tracked (GHL sends plain text). Only sent/failed/pending.
- SMS channel is intentionally excluded.
- No automatic retry yet.

Please output:
(A) Mermaid `flowchart` of components (UI pages, tables, engine, cron, GHL, patient) with
    arrows for read/write, grouped in subgraphs (Frontend / Database / Engine / External).
(B) Mermaid `sequenceDiagram` for the scheduled-send flow (Cron → Engine → DB → GHL → Patient → Logs → Staff).
(C) A short bullet legend explaining the honesty constraints.
Keep labels concise. Malay labels are fine where natural.
```

---

### Petua
- Kalau nak rajah lebih ringkas: tambah *"Keep it high-level, max 15 nodes."*
- Kalau nak fokus satu aliran: buang bahagian lain, minta **hanya sequence diagram**.
- Untuk render Mermaid: guna https://mermaid.live atau sambungan Markdown yang menyokong Mermaid.
