// Treatment Packages — gates patient access to features
const PACKAGES = [
  { id:'pkg-777-free', name:'777 FREE', desc:'7-hari starter · percuma', price:0, icon:'🎁', bg:'bg-cream', tier:'free', accessLevel:'basic',
    inclusions:['7 Hari Webinar (Diet, Rohani, Ripple)','7 Gaya Hidup Fitrah','7 Resepi Fitrah','Whatsapp Group Support']},
  { id:'pkg-777-vip', name:'777 VIP', desc:'VIP starter · coaching & support', price:999, icon:'⭐', bg:'bg-gold-light', tier:'vip', accessLevel:'standard',
    inclusions:['7 Hari Webinar (Diet, Rohani, Ripple)','7 Gaya Hidup Fitrah','7 Resepi Fitrah','Whatsapp Group Support 777 VIP','Daily Workbook','Perubatan Rohani Bersama Sheikh Fares','1:1 Coaching Diet / Nutrisi 1x Sebulan','Video Series Hakeema','Kurma Ajwa 49 Biji','Barley 500g']},
  { id:'pkg-eol', name:'EOL', desc:'Entry-level · 1 madu + coaching', price:299, icon:'🍯', bg:'bg-navy-light', accessLevel:'standard',
    inclusions:['1 (500G) Young & Healthy Honey','Whatsapp Group Support','Akses Portal ISW','1 Sesi Konsultasi bersama Coach secara Online','Perubatan Rohani bersama Sheikh Fares']},
  { id:'pkg-eol-plus', name:'EOL+', desc:'Enhanced · 2 madu + coaching', price:499, icon:'🍯', bg:'bg-navy-light', accessLevel:'standard',
    inclusions:['2 (500G) Young & Healthy Honey','Whatsapp Group Support','Akses Portal ISW','1 Sesi Konsultasi bersama Coach secara Online','Perubatan Rohani bersama Sheikh Fares']},
  { id:'pkg-obg', name:'OBG', desc:'Comprehensive cleansing', price:1499, icon:'🌿', bg:'bg-green-light', accessLevel:'standard',
    inclusions:['10 KG IB','8 KG YHPG','Starter Kit','12 Botol Air Afiyah','7 Botol Air Za\'afaran']},
  { id:'pkg-obd1', name:'OBD 1', desc:'Detox · 6 KG tier', price:1999, icon:'🌱', bg:'bg-terracotta-light', accessLevel:'standard',
    inclusions:['6 KG LTH','6 KG LTHPG','Starter Kit','12 Botol Air Afiyah','7 Botol Air Za\'afaran']},
  { id:'pkg-obdx1', name:'OBDX 1', desc:'Detox · 12 KG tier', price:3499, icon:'🌱', bg:'bg-gold-light', accessLevel:'premium',
    inclusions:['12 KG LTH','12 KG LTHPG','Starter Kit','21 Botol Air Afiyah','7 Botol Air Za\'afaran']},
  { id:'pkg-obdy1', name:'OBDY 1', desc:'Detox · 21 KG premium', price:5999, icon:'🌱', bg:'bg-gold-light', accessLevel:'premium',
    inclusions:['21 KG LTH','21 KG LTHPG','Starter Kit','33 Botol Air Afiyah','7 Botol Air Za\'afaran']},
  { id:'pkg-obp1', name:'OBP 1', desc:'Premium · 6 KG + full terapi', price:2999, icon:'💎', bg:'bg-navy-light', accessLevel:'premium',
    inclusions:['6 KG IB','6 KG YHPG','Starter Kit','12 Botol Air Afiyah','7 Botol Air Za\'afaran','1 Set Herba Kolon','1 Set Enema Kit','1 Set Mesin Ozon','4 Set IV Saline Drip','20 Sesi Herba Thoharah','1 Set DNA Test Kit','6 Kelas Online New Life Challenge','Bimbingan Terapi Peminuman IB, YHPG','Bimbingan Terapi Zikir Bersanad','Bimbingan Terapi Diet dan Nutrisi','Bimbingan Terapi Gaya Hidup Fitrah','Bimbingan Terapi Herba Thoharah','Bimbingan Terapi IV Saline Drip','Konsultasi DNA bersama Coach','Perubatan Coach','Perubatan Rohani secara Online bersama Coach Fares','Sesi Soal Jawab bersama Nutrisionis']},
  { id:'pkg-obpx1', name:'OBPX 1', desc:'Premium · 12 KG + full terapi', price:5499, icon:'💎', bg:'bg-teal/10', accessLevel:'premium',
    inclusions:['12 KG IB','12 KG YHPG','Starter Kit','21 Botol Air Afiyah','7 Botol Air Za\'afaran','4 Set Herba Kolon','1 Set Enema Kit','1 Set Mesin Ozon','4 Set IV Saline Drip','26 Sesi Herba Thoharah','1 Set DNA Test Kit','6 Kelas Online New Life Challenge','Bimbingan Terapi Peminuman IB, YHPG','Bimbingan Terapi Zikir Bersanad','Bimbingan Terapi Diet dan Nutrisi','Bimbingan Terapi Gaya Hidup Fitrah','Bimbingan Terapi Herba Thoharah','Bimbingan Terapi IV Saline Drip','Konsultasi DNA bersama Coach','Perubatan Coach','Perubatan Rohani secara Online bersama Coach Fares','Sesi Soal Jawab bersama Nutrisionis']},
  { id:'pkg-obpy1', name:'OBPY 1', desc:'Premium elite · 21 KG + full terapi', price:8999, icon:'👑', bg:'bg-gold-light', accessLevel:'premium',
    inclusions:['21 KG IB','21 KG YHPG','Starter Kit','33 Botol Air Afiyah','7 Botol Air Za\'afaran','7 Set Herba Kolon','1 Set Enema Kit','1 Set Mesin Ozon','4 Set IV Saline Drip','32 Sesi Herba Thoharah','1 Set DNA Test Kit','6 Kelas Online New Life Challenge','Bimbingan Terapi Peminuman IB, YHPG','Bimbingan Terapi Zikir Bersanad','Bimbingan Terapi Diet dan Nutrisi','Bimbingan Terapi Gaya Hidup Fitrah','Bimbingan Terapi Herba Thoharah','Bimbingan Terapi IV Saline Drip','Konsultasi DNA bersama Coach','Perubatan Coach','Perubatan Rohani secara Online bersama Coach Fares','Sesi Soal Jawab bersama Nutrisionis']},
];

window.PACKAGES = PACKAGES;
