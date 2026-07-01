# Flow Inventori — ISW System

Dokumentasi lengkap flow inventori, merangkumi auto-PR, auto-deduct bekalan sesi, sync produk shop, dan helicopter view ekosistem.

Sumber kod rujukan:
- [database/step_inventory_auto_trigger.sql](../database/step_inventory_auto_trigger.sql)
- [shared/inventoryDeduct.js](../shared/inventoryDeduct.js)
- [shared/stockSync.js](../shared/stockSync.js)
- [roles/staff/inventory.html](../roles/staff/inventory.html)
- [roles/staff/inventory-detail.html](../roles/staff/inventory-detail.html)

---

## 1. Flow Utama Inventori (Auto-PR)

Trigger PR berlaku **hanya bila `qty_in_stock` TURUN** dan lulus 3 check: threshold, cooldown 24 jam, duplicate guard.

```mermaid
flowchart TD
    A[Inventori - Master Stok] --> B[Detail Item]
    A --> C[Tambah Item]
    A --> LI[List Inventori]

    B --> LS[Laras Stock]
    LS --> QTY[Qty masuk/keluar/set]
    QTY --> UPD[(UPDATE qty_in_stock)]

    C --> KD[Keyin: Nama, Jenis Penggunaan,<br/>Kategori, Unit]
    KD --> SK[Stock Semasa,<br/>Stock Min, Stock Max,<br/>Auto-Reorder Qty]
    SK -->|Submit| LI

    UPD --> TRG{Trigger:<br/>qty_in_stock TURUN?}
    TRG -->|Naik/sama| LI
    TRG -->|Turun| TH{≤ threshold?<br/>30% × max_qty<br/>atau min_qty}
    TH -->|Tak| LI
    TH -->|Ya| CD{Cooldown<br/>24 jam?}
    CD -->|Masih cooldown| LI
    CD -->|OK| DUP{Dah ada PR<br/>pending/approved?}
    DUP -->|Ya skip| LI
    DUP -->|Tiada| GPR[Generate PR<br/>qty = max - semasa<br/>atau auto_reorder_qty]

    GPR --> LP[List Permohonan]
    LP --> TG{requires_approval?}
    TG -->|False| AA[Status: approved<br/>auto-skip]
    TG -->|True| PA[Status: pending_approval]

    PA --> MR{Manager Review}
    MR -->|Rejected| CC[Closed: Out of Stock]
    MR -->|Approved| PB[Pembelian]
    AA --> PB

    PB --> DB[Dah Beli]
    DB --> PUR[Purchased<br/>+ qty masuk inventori]
    PUR --> UPD
```

**Nota penting:**
- `threshold = 30% × max_qty` jika `max_qty` diset, jika tidak fallback `min_qty`.
- `reorder_qty = auto_reorder_qty` jika ada, jika tidak `max_qty - qty_in_stock`.
- Cooldown 24 jam disimpan dalam `last_auto_po_at`.
- Duplicate guard: skip jika ada PR `pending_approval` atau `approved` untuk item sama.

---

## 2. Flow Auto-Deduct Bekalan Sesi F2F

Bila staff mark sesi 'hadir', sistem auto-deduct bekalan dari `coaching_schedule[weekIndex].supplies`.

```mermaid
flowchart TD
    S[Staff: Mark Sesi Hadir] --> CHK1{Sesi extension?}
    CHK1 -->|Ya| SKIP1[Skip — tiada bekalan]
    CHK1 -->|Tak| GET[Ambil plan.coaching_schedule<br/>weekIndex.supplies]

    GET --> CHK2{Mode = online?}
    CHK2 -->|Ya| SKIP2[Skip — sesi online]
    CHK2 -->|Tak| LOOP[Loop setiap supply item]

    LOOP --> V1{item_id ada?}
    V1 -->|Tak| SK[Skip item]
    V1 -->|Ya| V2{qty > 0?}
    V2 -->|Tak| SK
    V2 -->|Ya| V3{auto_stock<br/>≠ false?}
    V3 -->|Off| SK
    V3 -->|On| FETCH[Fetch psy_inventory_items<br/>by item_id]

    FETCH --> CALC[newQty = max 0,<br/>currentQty - usage]
    CALC --> UPD[(UPDATE qty_in_stock)]
    UPD --> AUD[Audit log:<br/>inventory.auto_deducted]
    AUD --> BAN[Banner ke staff:<br/>'Bekalan ditolak X-N']

    UPD -.->|trigger fire| TRG[Auto-PR flow<br/>lihat Flow #1]
```

---

## 3. Flow Sync Inventori ↔ Produk Shop (dwi-arah)

Stok sync antara `psy_inventory_items` dan `psy_products` melalui match nama (case-insensitive, trim).

```mermaid
flowchart LR
    subgraph STAFF[Staff Side]
        IE[Inventory-Detail<br/>laras stok]
        PE[Product-Edit<br/>update stok]
        PA[Products: Tambah baru]
    end

    subgraph DB[(Database)]
        INV[(psy_inventory_items)]
        PRD[(psy_products)]
    end

    subgraph PATIENT[Patient Side]
        SH[Shop: lihat produk]
        CO[Checkout / Beli]
    end

    IE -->|update qty_in_stock| INV
    INV -.->|syncStockToProducts<br/>match by name| PRD

    PE -->|update stock| PRD
    PRD -.->|syncStockToInventory<br/>match by name| INV

    PA -->|insert produk baru| PRD
    PRD -.->|ensureInventoryCounterpart<br/>auto-create kalau tiada| INV

    PRD --> SH
    SH --> CO
    CO -->|deduct stock<br/>via FK link / nama| PRD
    CO -.->|sync| INV
```

---

## 4. Helicopter View — Ekosistem Penuh

Semua sumber pergerakan stok dan kesannya ke auto-PR.

```mermaid
flowchart TD
    subgraph SRC[Sumber Pergerakan Stok]
        M1[Manual: Laras Stock]
        M2[Auto-Deduct: Sesi F2F hadir]
        M3[Patient Checkout di Shop]
        M4[Pembelian Restock]
    end

    M1 --> CORE
    M2 --> CORE
    M3 --> CORE
    M4 --> CORE

    CORE[(psy_inventory_items<br/>qty_in_stock berubah)]

    CORE -->|Sync nama| PROD[(psy_products.stock)]
    CORE -->|Trigger DB| AUTO{Auto-PR Logic<br/>threshold + cooldown<br/>+ dup guard}

    AUTO -->|Lulus semua check| PR[psy_inventory_requests<br/>pending_approval / approved]
    PR --> MGR{Manager / Auto-Skip}
    MGR -->|Approved| BUY[Pembelian]
    BUY --> M4
    MGR -->|Rejected| OUT[Out of Stock]
```

---

## Ringkasan Rule

| Rule | Nilai | Sumber |
|---|---|---|
| Threshold auto-PR | `30% × max_qty` atau `min_qty` (fallback) | step_inventory_auto_trigger.sql |
| Cooldown | 24 jam (`last_auto_po_at`) | step_inventory_auto_trigger.sql |
| Duplicate guard | Skip jika ada PR `pending_approval`/`approved` untuk item sama | step_inventory_auto_trigger.sql |
| Reorder qty | `auto_reorder_qty` atau `max_qty - qty_in_stock` | step_inventory_auto_trigger.sql |
| Trigger arah | Hanya bila qty TURUN | step_inventory_auto_trigger.sql |
| Auto-deduct skip | extension, online, qty=0, auto_stock=false | inventoryDeduct.js |
| Sync match | Nama case-insensitive + trim | stockSync.js |
