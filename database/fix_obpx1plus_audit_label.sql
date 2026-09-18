-- Fix satu rekod audit log yang silap label sebab bug editId-reassignment
-- di pakej-edit.html savePackage() (baiki 18 Sept 2026 — lihat commit/kod
-- semasa untuk fix). Pakej "OBPX1+" dicipta 28 Ogos 2026 tapi audit log
-- tersilap catat action='package.updated' sedangkan sepatutnya
-- 'package.created' (satu-satunya entri log untuk pakej ni, pada masa
-- creation yang tepat).

UPDATE psy_audit_log
SET action = 'package.created'
WHERE id = '4ce9496d-60a4-49f9-8127-d2d3c3aa1449'
  AND target = 'a49ba22d-d5d4-48cd-a992-5dc588bd5c9c'
  AND action = 'package.updated'
RETURNING id, action, target, created_at;
