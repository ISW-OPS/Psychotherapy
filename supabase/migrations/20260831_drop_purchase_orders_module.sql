-- Modul Purchase Orders (P15-17) DIBUANG — proses sebenar syarikat tak hantar
-- PO rasmi ke supplier; staff beli terus lepas PR diluluskan ("Tandakan Dibeli"
-- di Purchase Requests dah cukup, terus update stok). Jadual ni cuma perlu
-- dibuang KALAU 20260830_purchase_orders_module.sql sempat di-run di
-- testing/prod sebelum keputusan ni — kalau belum, migration ni tiada kesan.

DROP TABLE IF EXISTS psy_purchase_order_items;
DROP TABLE IF EXISTS psy_purchase_orders;
DROP SEQUENCE IF EXISTS psy_po_number_seq;
DROP FUNCTION IF EXISTS psy_set_po_number();
