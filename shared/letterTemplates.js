// ============================================================
// LETTER RENDERER — letterhead tetap + body templat dinamik
// ============================================================

const CLINIC = {
  name: 'IBNU SINA WELLNESS',
  address: 'Lot 331, Lorong Senyum Matahari B, Country Heights, 43000 Kajang, Selangor.',
  phone: '03-8966 3696',
  legalName: 'Ibnu Sina Wellness Sdn Bhd (1319021-P)',
  legalAddress: 'Lot 331 Lorong Senyum Matahari B, Country Heights 43000 Kajang, Selangor Malaysia',
  legalPhones: '+60 17 775 6615 / +60 17 426 5661',
};

// Placeholder auto-isi — semua di-load dari DB (psy_letter_auto_fields)
// `source`: 'patient' | 'staff' | 'system'
// `from(ctx)`: ctx = { patient, staff, refNumber }
const AUTO_FIELDS = [];

// Build values lengkap (auto + manual)
// signature: buildLetterValues(patient, manualFieldValues, opts)
// opts: { staff, refNumber }
function buildLetterValues(patient, manualFieldValues, opts) {
  const ctx = { patient, staff: opts?.staff || null, refNumber: opts?.refNumber || '' };
  const values = {};
  AUTO_FIELDS.forEach(f => { values[f.key] = f.from(ctx); });
  Object.assign(values, manualFieldValues || {});
  return values;
}

// Plain substitution — replace [KEY] dengan value (tiada HTML wrap)
function substitutePlain(text, values) {
  let out = text || '';
  Object.entries(values || {}).forEach(([k, v]) => {
    const safe = (v === null || v === undefined) ? '' : String(v);
    out = out.replace(new RegExp(`\\[${k}\\]`, 'g'), safe);
  });
  return out;
}

// Replace [PLACEHOLDER] dalam body + format paragraf
function fillBody(bodyText, values) {
  let out = bodyText || '';
  Object.entries(values).forEach(([k, v]) => {
    const safe = (v === null || v === undefined) ? '' : String(v).replace(/</g, '&lt;');
    out = out.replace(new RegExp(`\\[${k}\\]`, 'g'), `<strong>${safe}</strong>`);
  });
  // Tukar newline ke <br>
  return out.split(/\n\n+/).map(p => `<p>${p.replace(/\n/g, '<br>')}</p>`).join('');
}

// Render surat penuh: letterhead + body + signature + footer
// `logoUrl` — path ke logo (relative dari page)
function renderLetterFull({
  logoUrl, template, values, refNumber, signerName, signerRole, signatureDataUrl, todayStr,
}) {
  const today = todayStr || new Date().toLocaleDateString('ms-MY', { day: '2-digit', month: 'long', year: 'numeric' });
  const bodyHtml = fillBody(template.body, values);
  // Substitute [KEY] dalam recipient & title juga
  const recipientRaw = substitutePlain(template.recipient || '', values);
  const recipient = recipientRaw.replace(/</g, '&lt;').replace(/\n/g, '<br>');
  const title = substitutePlain(template.title || '', values).toUpperCase().replace(/</g, '&lt;');

  return `
    <div style="font-family:'Inter','Helvetica',Arial,sans-serif;font-size:11pt;line-height:1.6;color:#000;padding:40px 50px;max-width:800px;margin:0 auto;background:white;">

      <!-- Letterhead -->
      <div style="display:flex;align-items:flex-start;justify-content:space-between;gap:20px;margin-bottom:30px">
        <div style="display:flex;align-items:center;gap:14px">
          ${logoUrl ? `<img src="${logoUrl}" alt="ISW" style="width:120px;height:auto;object-fit:contain">` : ''}
        </div>
      </div>

      <div style="margin-bottom:24px">
        <div style="font-weight:bold;font-size:12pt">${CLINIC.name}</div>
        <div>${CLINIC.address.replace(/, /g, ',<br>')}</div>
        <div>Tel: ${CLINIC.phone}</div>
      </div>

      <div style="margin-bottom:20px">Tarikh: ${today}</div>

      ${refNumber ? `<div style="margin-bottom:16px;font-size:10pt;color:#444">Ruj: ${refNumber}</div>` : ''}

      ${recipient ? `<div style="margin-bottom:16px"><div>Kepada:</div><div style="font-weight:bold">${recipient}</div></div>` : ''}

      <p>Tuan/Puan,</p>

      ${title ? `<h3 style="text-decoration:underline;margin:16px 0">${title}</h3>` : ''}

      ${bodyHtml}

      <p style="margin-top:24px">Sekian, terima kasih.</p>
      <p>Yang Benar,</p>

      <div style="margin-top:32px">
        ${signatureDataUrl
          ? `<img src="${signatureDataUrl}" alt="signature" style="max-height:60px;max-width:180px;display:block;margin-bottom:4px">`
          : '<div style="height:48px"></div>'}
        <div>……………………………</div>
        <div style="font-weight:bold">${signerName || ''}</div>
        ${signerRole ? `<div>${signerRole}</div>` : ''}
        <div>${CLINIC.name}</div>
      </div>

      <div style="margin-top:80px;padding-top:16px;border-top:1px solid #ccc;display:grid;grid-template-columns:1fr 1fr;gap:24px;font-size:9pt;color:#666">
        <div>
          <div style="font-style:italic">This is an electronically generated document and does not require a physical signature.</div>
        </div>
        <div style="text-align:right">
          <div>${CLINIC.legalName}</div>
          <div>${CLINIC.legalAddress}</div>
          <div>Tel: ${CLINIC.legalPhones}</div>
        </div>
      </div>

    </div>
  `;
}

// Open letter dalam tab baru (untuk preview / print)
function openLetterTab(html, title) {
  const w = window.open('', '_blank');
  w.document.write(`<!DOCTYPE html><html><head><title>${(title || 'Surat').replace(/</g,'&lt;')}</title>
    <style>
      @page { size: A4; margin: 0; }
      body { margin: 0; background: #f5f5f5; }
      .actions { position: fixed; top: 12px; right: 12px; display: flex; gap: 8px; z-index: 100; }
      .btn { background: #1e3a5f; color: white; padding: 8px 16px; border: none; border-radius: 8px; font-family: sans-serif; font-size: 12px; cursor: pointer; }
      .btn.gray { background: #999; }
      @media print { .actions { display: none; } body { background: white; } }
    </style></head><body>
    <div class="actions">
      <button class="btn" onclick="window.print()">Cetak / Simpan PDF</button>
      <button class="btn gray" onclick="window.close()">Tutup</button>
    </div>
    ${html}</body></html>`);
  w.document.close();
}

// Format value based on type
function formatValue(val, format) {
  if (val === null || val === undefined || val === '') return '';
  if (format === 'date') {
    try { return new Date(val).toLocaleDateString('ms-MY', { day: '2-digit', month: 'long', year: 'numeric' }); }
    catch { return val; }
  }
  if (format === 'currency') return 'RM ' + Number(val).toFixed(2);
  return String(val);
}

// Load semua auto-fields dari DB
async function loadCustomAutoFields() {
  if (!window.db) return;
  try {
    const { data } = await window.db.from('psy_letter_auto_fields')
      .select('*').eq('is_active', true).order('sort_order', { ascending: true });
    AUTO_FIELDS.length = 0;
    (data || []).forEach(cf => {
      AUTO_FIELDS.push({
        key:    cf.key,
        source: cf.source,
        label:  cf.label,
        is_default: !!cf.is_default,
        custom_id: cf.id,
        data_path: cf.data_path,
        format_type: cf.format_type,
        from: (ctx) => {
          if (cf.source === 'system') {
            if (cf.data_path === '__today__') return new Date().toLocaleDateString('ms-MY', { day: '2-digit', month: 'long', year: 'numeric' });
            if (cf.data_path === '__ref_number__') return ctx.refNumber || '';
            return '';
          }
          const obj = cf.source === 'patient' ? ctx.patient : cf.source === 'staff' ? ctx.staff : null;
          if (!obj) return '';
          const val = cf.data_path.split('.').reduce((o, k) => (o == null ? null : o[k]), obj);
          return formatValue(val, cf.format_type);
        },
      });
    });
  } catch (e) {
    console.warn('Failed to load auto fields:', e);
  }
}

if (typeof window !== 'undefined') {
  window.LETTER_CLINIC = CLINIC;
  window.AUTO_FIELDS = AUTO_FIELDS;
  window.buildLetterValues = buildLetterValues;
  window.fillBody = fillBody;
  window.substitutePlain = substitutePlain;
  window.renderLetterFull = renderLetterFull;
  window.openLetterTab = openLetterTab;
  window.loadCustomAutoFields = loadCustomAutoFields;
}
