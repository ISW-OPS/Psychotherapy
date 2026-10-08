-- ═══════════════════════════════════════════════════════════════════════════
-- Audit #118 / #B2-118 — Conflict checking utk Reaksi & Tindakan
-- Jadual baharu psy_reaksi_conflict_pairs: staf tetapkan sendiri pasangan
-- tindakan yang bercanggah (cth "Tambah air" vs "Kurangkan air") bila tercadang
-- serentak — sistem TIDAK cuba teka secara automatik berdasarkan makna teks.
-- + kolum conflict_pairs pada psy_reaksi_advice_log (sebab bercanggah utk staf).
-- Selamat dijalankan berulang kali (semua CREATE/ADD guna IF NOT EXISTS).
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS psy_reaksi_conflict_pairs (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  action_id_1 UUID NOT NULL REFERENCES psy_reaksi_actions(id) ON DELETE CASCADE,
  action_id_2 UUID NOT NULL REFERENCES psy_reaksi_actions(id) ON DELETE CASCADE,
  note        TEXT,                                   -- sebab bercanggah (pilihan)
  created_by  UUID REFERENCES psy_profiles(id),
  created_at  TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT chk_reaksi_conflict_pair_distinct CHECK (action_id_1 <> action_id_2)
);

-- Elak pasangan duplicate tak kira arah (A,B) sama dgn (B,A) — LEAST/GREATEST
-- supaya index tak kira susunan 2 tindakan diisi dalam borang.
CREATE UNIQUE INDEX IF NOT EXISTS uq_reaksi_conflict_pair
  ON psy_reaksi_conflict_pairs (LEAST(action_id_1, action_id_2), GREATEST(action_id_1, action_id_2));

ALTER TABLE psy_reaksi_conflict_pairs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage reaksi conflict pairs" ON psy_reaksi_conflict_pairs;
CREATE POLICY "Staff manage reaksi conflict pairs" ON psy_reaksi_conflict_pairs FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Authenticated read reaksi conflict pairs" ON psy_reaksi_conflict_pairs;
CREATE POLICY "Authenticated read reaksi conflict pairs" ON psy_reaksi_conflict_pairs FOR SELECT
  USING (auth.uid() IS NOT NULL);

COMMENT ON COLUMN psy_reaksi_conflict_pairs.note IS 'Sebab bercanggah — dipaparkan kpd staf, pilihan';

-- Pasangan tindakan bercanggah yg dikesan semasa generateReaksiAdvice() — array
-- of {action_id_1, title_1, action_id_2, title_2}. Diguna reaksi-laporan.html
-- papar SEBAB khusus di kad "Perlu Disemak" (bukan setakat "≥2 simptom" generik).
ALTER TABLE psy_reaksi_advice_log ADD COLUMN IF NOT EXISTS conflict_pairs JSONB NOT NULL DEFAULT '[]';
