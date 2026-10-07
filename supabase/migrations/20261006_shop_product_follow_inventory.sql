-- Produk Shop ikut status Inventori secara automatik:
--  • item Inventori jadi Inactive/Discontinued → produk dipaut dinyahaktifkan (is_active=false, status='inactive')
--  • item dipadam dari Inventori → produk dipaut dinyahaktifkan
--  • produk ditukar pautan ke item yang sudah tak aktif → produk terus dinyahaktifkan
-- Tiada auto-aktif semula: staf aktifkan semula secara manual bila sesuai.
-- Rujuk: database/schema/14_products_inventory.sql

CREATE OR REPLACE FUNCTION psy_inv_item_is_inactive(p_row JSONB)
RETURNS BOOLEAN LANGUAGE sql IMMUTABLE AS $$
  SELECT COALESCE(p_row->>'status',
                  CASE WHEN p_row->>'is_active' = 'false' THEN 'inactive' ELSE 'active' END) <> 'active'
$$;

CREATE OR REPLACE FUNCTION psy_sync_shop_products_on_inventory_change()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF psy_inv_item_is_inactive(to_jsonb(NEW)) THEN
    UPDATE psy_products
       SET is_active = false, status = 'inactive', updated_at = now()
     WHERE inventory_item_id = NEW.id
       AND (is_active IS DISTINCT FROM false OR status IS DISTINCT FROM 'inactive');
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_sync_shop_products_on_inventory_change ON psy_inventory_items;
CREATE TRIGGER trg_sync_shop_products_on_inventory_change
  AFTER INSERT OR UPDATE ON psy_inventory_items
  FOR EACH ROW EXECUTE FUNCTION psy_sync_shop_products_on_inventory_change();

CREATE OR REPLACE FUNCTION psy_deactivate_shop_products_on_inventory_delete()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  UPDATE psy_products
     SET is_active = false, status = 'inactive', updated_at = now()
   WHERE inventory_item_id = OLD.id;
  RETURN OLD;
END $$;

DROP TRIGGER IF EXISTS trg_deactivate_shop_products_on_inventory_delete ON psy_inventory_items;
CREATE TRIGGER trg_deactivate_shop_products_on_inventory_delete
  BEFORE DELETE ON psy_inventory_items
  FOR EACH ROW EXECUTE FUNCTION psy_deactivate_shop_products_on_inventory_delete();

CREATE OR REPLACE FUNCTION psy_check_shop_product_link()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  v_item JSONB;
BEGIN
  IF NEW.inventory_item_id IS NOT NULL THEN
    SELECT to_jsonb(i) INTO v_item FROM psy_inventory_items i WHERE i.id = NEW.inventory_item_id;
    IF v_item IS NOT NULL AND psy_inv_item_is_inactive(v_item) THEN
      NEW.is_active := false;
      NEW.status := 'inactive';
    END IF;
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_check_shop_product_link ON psy_products;
CREATE TRIGGER trg_check_shop_product_link
  BEFORE INSERT OR UPDATE OF inventory_item_id ON psy_products
  FOR EACH ROW EXECUTE FUNCTION psy_check_shop_product_link();
