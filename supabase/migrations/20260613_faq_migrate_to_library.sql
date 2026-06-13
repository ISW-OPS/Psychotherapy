-- Migrate FAQ data from psy_faq_sections/psy_faq_items → psy_library_items
-- Run AFTER 20260613_faq_overhaul_body.sql (tables must exist)

INSERT INTO psy_library_items (
  item_id, title, media_type, content_type, topic,
  content_body, icon, gradient, category,
  status, is_active, sort_order
)
SELECT
  'faq-' || lower(s.code) || '-' || lpad(i.sort_order::text, 2, '0')  AS item_id,
  i.soalan                                                              AS title,
  'faq'                                                                 AS media_type,
  'FAQ'                                                                 AS content_type,
  s.title                                                               AS topic,
  '<p>' || i.jawapan || '</p>'                                          AS content_body,
  '❓'                                                                   AS icon,
  'from-navy to-teal'                                                   AS gradient,
  'navy'                                                                AS category,
  'published'                                                           AS status,
  true                                                                  AS is_active,
  (s.sort_order * 100) + i.sort_order                                   AS sort_order
FROM psy_faq_sections s
JOIN psy_faq_items i ON i.section_id = s.id
ORDER BY s.sort_order, i.sort_order
ON CONFLICT (item_id) DO NOTHING;

SELECT 'FAQ migrated OK' AS status, count(*) AS jumlah FROM psy_library_items WHERE media_type = 'faq';
