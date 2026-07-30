-- Toggle Biasa/Teruk di Catatan Harian (Reaksi Pemulihan)
-- Teruk → Merah terus, tak kira tahap_risiko baseline simptom.
-- Staff kawal per-simptom sama ada pilihan ni dipapar (reaksi-item.html).
ALTER TABLE psy_reaksi_item ADD COLUMN IF NOT EXISTS boleh_pilih_teruk BOOLEAN NOT NULL DEFAULT true;

COMMENT ON COLUMN psy_reaksi_item.boleh_pilih_teruk IS 'true = pesakit tanda Biasa/Teruk di Catatan Harian (Teruk→Merah terus, apa-apa tahap_risiko pun); false = tiada pilihan, terus ikut tahap_risiko';
