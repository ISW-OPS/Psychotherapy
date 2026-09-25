-- Audit management batch 3 (25 Sept 2026), Tier 7 #2 — isu keselamatan:
-- psy_library_items policy lama "Anyone read library" USING (true) bermakna
-- sekatan package_ids cuma di UI (isLocked() client-side), sesiapa (termasuk
-- tak login) boleh baca content_url semua rekod terus melalui API. Gantikan
-- dgn policy yang benar-benar kuatkuasa sekatan pakej di server.
-- Rujuk: database/schema/13_library_faq.sql, memory project_audit_tier6_7_sept2026.

DROP POLICY IF EXISTS "Anyone read library" ON psy_library_items;
DROP POLICY IF EXISTS "Patients read allowed library" ON psy_library_items;
CREATE POLICY "Patients read allowed library" ON psy_library_items FOR SELECT
  TO authenticated
  USING (
    is_active = true
    AND (
      package_ids IS NULL OR array_length(package_ids, 1) IS NULL
      OR EXISTS (
        SELECT 1 FROM psy_patients p
        LEFT JOIN psy_packages pk
          ON pk.id::text = p.active_package_id OR pk.package_id = p.active_package_id
        WHERE p.user_id = auth.uid()
          AND (p.active_package_id = ANY(package_ids) OR pk.package_id = ANY(package_ids))
      )
    )
  );
