-- Tukar nama kategori "Peredaran Darah" -> "Jantung" (permintaan staf, 1 Okt 2026).
-- Mencerminkan laluan sama macam rename manual via UI Kategori (reaksi-item.html
-- ktEditSave()) — cascade ke psy_reaksi_item.kumpulan + psy_reaksi_actions.kategori.
-- Rujuk: database/schema/12_reaksi.sql

UPDATE psy_reaksi_kategori SET nama = 'Jantung', ikon = '❤️', updated_at = now()
  WHERE nama = 'Peredaran Darah';

UPDATE psy_reaksi_item SET kumpulan = 'Jantung', ikon = '❤️'
  WHERE kumpulan = 'Peredaran Darah';

UPDATE psy_reaksi_actions SET kategori = 'Jantung'
  WHERE kategori = 'Peredaran Darah';
