-- ============================================================
-- step_inventory_auto_trigger.sql
-- Auto-create psy_inventory_requests bila stok turun ≤ threshold.
--
-- Threshold:
--   - Kalau max_qty diset → 30% daripada max_qty
--   - Kalau tidak → min_qty (fallback)
--
-- Status request:
--   - requires_approval = TRUE  → 'pending_approval' (manager kena approve)
--   - requires_approval = FALSE → 'approved' (staff terus boleh beli)
--
-- Duplicate guard:
--   - Skip kalau dah ada request status 'pending_approval' atau 'approved'
--     untuk item yang sama (belum purchased).
--   - Cooldown 24 jam guna last_auto_po_at — elak spam masa stok
--     turun-naik berkali-kali dalam masa singkat.
-- ============================================================

CREATE OR REPLACE FUNCTION psy_inventory_auto_request()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_threshold       NUMERIC;
  v_existing_count  INT;
  v_reorder_qty     NUMERIC;
  v_status          TEXT;
  v_target          NUMERIC;
BEGIN
  -- Hanya bertindak bila qty_in_stock benar-benar berubah & turun
  IF NEW.qty_in_stock IS NULL OR NEW.qty_in_stock = OLD.qty_in_stock THEN
    RETURN NEW;
  END IF;
  IF NEW.qty_in_stock > OLD.qty_in_stock THEN
    RETURN NEW;  -- stok naik (restock) — jangan trigger
  END IF;

  -- Kira threshold
  IF NEW.max_qty IS NOT NULL AND NEW.max_qty > 0 THEN
    v_threshold := NEW.max_qty * 0.30;
  ELSE
    v_threshold := COALESCE(NEW.min_qty, 0);
  END IF;

  IF v_threshold <= 0 THEN
    RETURN NEW;
  END IF;

  IF NEW.qty_in_stock > v_threshold THEN
    RETURN NEW;  -- masih di atas threshold
  END IF;

  -- Cooldown 24 jam
  IF NEW.last_auto_po_at IS NOT NULL
     AND NEW.last_auto_po_at > now() - INTERVAL '24 hours' THEN
    RETURN NEW;
  END IF;

  -- Duplicate guard
  SELECT COUNT(*) INTO v_existing_count
  FROM psy_inventory_requests
  WHERE item_id = NEW.id
    AND status IN ('pending_approval', 'approved');

  IF v_existing_count > 0 THEN
    RETURN NEW;
  END IF;

  -- Kira reorder qty
  IF NEW.max_qty IS NOT NULL AND NEW.max_qty > 0 THEN
    v_target := NEW.max_qty;
  ELSE
    v_target := COALESCE(NEW.min_qty, 0) * 3;
  END IF;

  v_reorder_qty := COALESCE(NEW.auto_reorder_qty,
                            GREATEST(1, v_target - NEW.qty_in_stock));

  -- Tentukan status ikut requires_approval
  v_status := CASE
                WHEN COALESCE(NEW.requires_approval, false) THEN 'pending_approval'
                ELSE 'approved'
              END;

  INSERT INTO psy_inventory_requests (
    item_id, item_name, qty_requested, unit_price, total_amount,
    reason, status, requested_by, requested_by_name, is_auto_generated
  ) VALUES (
    NEW.id,
    NEW.name,
    v_reorder_qty,
    NULL,
    NULL,
    format('Auto-trigger: stok %s%s ≤ threshold %s%s. Sila beli %s%s.',
           NEW.qty_in_stock, COALESCE(NEW.unit, ''),
           ROUND(v_threshold, 2), COALESCE(NEW.unit, ''),
           v_reorder_qty, COALESCE(NEW.unit, '')),
    v_status,
    NULL,
    'Sistem (Auto)',
    true
  );

  -- Tanda cooldown
  NEW.last_auto_po_at := now();

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_psy_inventory_auto_request ON psy_inventory_items;

CREATE TRIGGER trg_psy_inventory_auto_request
BEFORE UPDATE OF qty_in_stock ON psy_inventory_items
FOR EACH ROW
EXECUTE FUNCTION psy_inventory_auto_request();

COMMENT ON FUNCTION psy_inventory_auto_request() IS
  'Auto-cipta inventory_request bila stok turun ≤ 30% max_qty (atau ≤ min_qty kalau max_qty tiada). Hormat requires_approval untuk status.';
