"""
ISW System - Flow Architecture PowerPoint Generator
Generates comprehensive flow diagrams for all system processes
"""

from pptx import Presentation
from pptx.util import Inches, Pt, Emu
from pptx.dml.color import RGBColor
from pptx.enum.text import PP_ALIGN
from pptx.util import Inches, Pt
from pptx.enum.shapes import MSO_SHAPE_TYPE
from pptx.oxml.ns import qn
import copy

# ── Colour Palette ──────────────────────────────────────────────────────────
NAVY       = RGBColor(0x1a, 0x2b, 0x4a)   # navy-dark
NAVY_MED   = RGBColor(0x1e, 0x3a, 0x5f)
GREEN      = RGBColor(0x2e, 0x7d, 0x32)
GREEN_LT   = RGBColor(0x43, 0xa0, 0x47)
GOLD       = RGBColor(0xf9, 0xa8, 0x25)
GOLD_LT    = RGBColor(0xff, 0xca, 0x28)
TEAL       = RGBColor(0x00, 0x89, 0x7b)
TEAL_LT    = RGBColor(0x26, 0xa6, 0x9a)
RED        = RGBColor(0xc6, 0x28, 0x28)
RED_LT     = RGBColor(0xe5, 0x39, 0x35)
ORANGE     = RGBColor(0xe6, 0x5c, 0x00)
PURPLE     = RGBColor(0x6a, 0x1b, 0x9a)
WHITE      = RGBColor(0xff, 0xff, 0xff)
LIGHT_GRAY = RGBColor(0xf5, 0xf5, 0xf5)
MED_GRAY   = RGBColor(0x9e, 0x9e, 0x9e)
DARK_GRAY  = RGBColor(0x42, 0x42, 0x42)

# ── Slide Dimensions (Widescreen 16:9) ──────────────────────────────────────
W = Inches(13.33)
H = Inches(7.5)

prs = Presentation()
prs.slide_width  = W
prs.slide_height = H

BLANK = prs.slide_layouts[6]  # blank layout


# ═══════════════════════════════════════════════════════════════════════════
#  HELPER FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════

def add_rect(slide, x, y, w, h, fill=NAVY, text="", font_size=11,
             text_color=WHITE, bold=False, radius=True, border_color=None,
             align=PP_ALIGN.CENTER, v_anchor="middle"):
    from pptx.enum.text import MSO_ANCHOR
    from pptx.oxml.ns import qn
    from lxml import etree

    if radius:
        shape = slide.shapes.add_shape(
            1,  # MSO_SHAPE_TYPE.ROUNDED_RECTANGLE
            Inches(x), Inches(y), Inches(w), Inches(h)
        )
        # Set corner radius
        try:
            sp = shape.element
            prstGeom = sp.find('.//' + qn('a:prstGeom'))
            if prstGeom is not None:
                avLst = prstGeom.find(qn('a:avLst'))
                if avLst is None:
                    avLst = etree.SubElement(prstGeom, qn('a:avLst'))
                gd = avLst.find(qn('a:gd'))
                if gd is None:
                    gd = etree.SubElement(avLst, qn('a:gd'))
                gd.set('name', 'adj')
                gd.set('fmla', 'val 20000')
        except Exception:
            pass
    else:
        shape = slide.shapes.add_shape(
            1,  # rectangle via index trick — use rounded anyway
            Inches(x), Inches(y), Inches(w), Inches(h)
        )

    shape.fill.solid()
    shape.fill.fore_color.rgb = fill

    if border_color:
        shape.line.color.rgb = border_color
        shape.line.width = Pt(1.5)
    else:
        shape.line.fill.background()

    tf = shape.text_frame
    tf.word_wrap = True

    if v_anchor == "middle":
        tf.auto_size = None

    p = tf.paragraphs[0]
    p.alignment = align
    run = p.add_run()
    run.text = text
    run.font.size = Pt(font_size)
    run.font.color.rgb = text_color
    run.font.bold = bold
    run.font.name = "Calibri"

    return shape


def add_text(slide, x, y, w, h, text, font_size=11, color=DARK_GRAY,
             bold=False, align=PP_ALIGN.LEFT, italic=False):
    txBox = slide.shapes.add_textbox(
        Inches(x), Inches(y), Inches(w), Inches(h)
    )
    tf = txBox.text_frame
    tf.word_wrap = True
    p = tf.paragraphs[0]
    p.alignment = align
    run = p.add_run()
    run.text = text
    run.font.size = Pt(font_size)
    run.font.color.rgb = color
    run.font.bold = bold
    run.font.italic = italic
    run.font.name = "Calibri"
    return txBox


def add_arrow(slide, x1, y1, x2, y2, color=MED_GRAY, width=1.5):
    """Draw a simple arrow connector (elbow) between two points."""
    from pptx.util import Pt
    from lxml import etree

    # Use a line connector
    connector = slide.shapes.add_connector(
        1,  # STRAIGHT connector
        Inches(x1), Inches(y1), Inches(x2), Inches(y2)
    )
    connector.line.color.rgb = color
    connector.line.width = Pt(width)
    return connector


def slide_header(slide, title, subtitle="", bg=NAVY):
    """Add a coloured header bar to a slide."""
    add_rect(slide, 0, 0, 13.33, 1.0, fill=bg,
             text=title, font_size=22, bold=True,
             text_color=WHITE, radius=False)
    if subtitle:
        add_text(slide, 0.3, 0.72, 10, 0.4, subtitle,
                 font_size=11, color=GOLD_LT, bold=False)


def add_chip(slide, x, y, w, h, label, fill=TEAL, text_color=WHITE, fs=9):
    add_rect(slide, x, y, w, h, fill=fill, text=label,
             font_size=fs, text_color=text_color, bold=True, radius=True)


def flow_box(slide, x, y, w, h, label, fill=NAVY_MED, fs=9.5):
    add_rect(slide, x, y, w, h, fill=fill, text=label,
             font_size=fs, text_color=WHITE, bold=True, radius=True)


def decision_box(slide, x, y, label, fill=GOLD, fs=9):
    """Diamond-ish shape using a tilted rectangle via shape type 4 (diamond)."""
    shape = slide.shapes.add_shape(
        4,  # diamond
        Inches(x), Inches(y), Inches(1.4), Inches(0.65)
    )
    shape.fill.solid()
    shape.fill.fore_color.rgb = fill
    shape.line.fill.background()
    tf = shape.text_frame
    tf.word_wrap = True
    p = tf.paragraphs[0]
    p.alignment = PP_ALIGN.CENTER
    run = p.add_run()
    run.text = label
    run.font.size = Pt(fs)
    run.font.color.rgb = DARK_GRAY
    run.font.bold = True
    run.font.name = "Calibri"
    return shape


def down_arrow(slide, x, y, color=MED_GRAY):
    """Small downward arrow label."""
    add_text(slide, x, y, 0.3, 0.25, "▼", font_size=9,
             color=color, align=PP_ALIGN.CENTER)


def right_arrow(slide, x, y, color=MED_GRAY):
    add_text(slide, x, y, 0.3, 0.25, "▶", font_size=9,
             color=color, align=PP_ALIGN.CENTER)


def section_label(slide, x, y, w, text, color=NAVY):
    add_text(slide, x, y, w, 0.3, text, font_size=10,
             color=color, bold=True)


# ═══════════════════════════════════════════════════════════════════════════
#  SLIDE 1 — COVER
# ═══════════════════════════════════════════════════════════════════════════
slide = prs.slides.add_slide(BLANK)
bg = slide.shapes.add_shape(1, 0, 0, W, H)
bg.fill.solid()
bg.fill.fore_color.rgb = NAVY
bg.line.fill.background()

# Decorative band
add_rect(slide, 0, 3.0, 13.33, 0.08, fill=GOLD, text="", radius=False)
add_rect(slide, 0, 3.1, 13.33, 0.04, fill=TEAL, text="", radius=False)

add_text(slide, 1, 1.0, 11, 0.8, "IBNU SINA WELLNESS (ISW)",
         font_size=38, color=GOLD, bold=True, align=PP_ALIGN.CENTER)
add_text(slide, 1, 1.9, 11, 0.6, "Healthcare Management & Psychotherapy Platform",
         font_size=18, color=WHITE, align=PP_ALIGN.CENTER)
add_text(slide, 1, 2.55, 11, 0.4, "System Flow Architecture & Process Diagrams",
         font_size=13, color=TEAL_LT, align=PP_ALIGN.CENTER)

# Module chips
chips = [
    ("KYC Management", TEAL, 1.2, 3.6),
    ("Treatment Plans", GREEN, 3.1, 3.6),
    ("Coaching Sessions", PURPLE, 5.0, 3.6),
    ("Risk Alerts", RED, 6.9, 3.6),
    ("Inventory", ORANGE, 8.8, 3.6),
    ("E-Commerce / Orders", NAVY_MED, 10.7, 3.6),
]
for lbl, clr, cx, cy in chips:
    add_chip(slide, cx, cy, 1.7, 0.38, lbl, fill=clr, fs=9)

# Role chips row
roles = [
    ("Patient", GREEN, 2.5, 4.3),
    ("Admin", RED, 4.1, 4.3),
    ("Doctor", TEAL, 5.7, 4.3),
    ("Coach", PURPLE, 7.3, 4.3),
    ("Manager", ORANGE, 8.9, 4.3),
]
for lbl, clr, cx, cy in roles:
    add_chip(slide, cx, cy, 1.3, 0.35, lbl, fill=clr, fs=9)

add_text(slide, 1, 5.0, 11, 0.4, "Tech Stack: Supabase (PostgreSQL)  •  HTML5  •  TailwindCSS  •  Vanilla JS",
         font_size=10, color=MED_GRAY, align=PP_ALIGN.CENTER, italic=True)
add_text(slide, 1, 5.4, 11, 0.35, "April 2026  |  ISW-OPS Team",
         font_size=10, color=MED_GRAY, align=PP_ALIGN.CENTER)


# ═══════════════════════════════════════════════════════════════════════════
#  SLIDE 2 — SYSTEM ARCHITECTURE OVERVIEW
# ═══════════════════════════════════════════════════════════════════════════
slide = prs.slides.add_slide(BLANK)
bg = slide.shapes.add_shape(1, 0, 0, W, H)
bg.fill.solid()
bg.fill.fore_color.rgb = LIGHT_GRAY
bg.line.fill.background()

slide_header(slide, "SYSTEM ARCHITECTURE OVERVIEW",
             "Roles, Modules & Access Layers", bg=NAVY)

# Three columns: Patient | Staff (4 roles) | Database
# Patient column
add_rect(slide, 0.2, 1.15, 2.8, 0.4, fill=GREEN,
         text="PATIENT PORTAL", font_size=11, bold=True, radius=True)
patient_modules = [
    "Dashboard & Announcements",
    "KYC Submission",
    "Package Selection & Purchase",
    "Treatment Plan View",
    "Daily Check-in / Mood",
    "Self-Help Library",
    "Product Shop & Orders",
    "Report Issue / Feedback",
    "Profile Management",
]
for i, m in enumerate(patient_modules):
    add_rect(slide, 0.2, 1.65 + i * 0.53, 2.8, 0.45,
             fill=WHITE, text=m, font_size=9, text_color=DARK_GRAY,
             bold=False, border_color=GREEN_LT, radius=True)

# Staff columns
staff_cols = [
    ("ADMIN", RED, [
        "Patient Management",
        "KYC Review & Approve",
        "Staff Registration",
        "Inventory & Stock",
        "Products & Packages",
        "Orders & Delivery",
        "Announcements",
        "Audit Log",
    ], 3.25),
    ("DOCTOR", TEAL, [
        "KYC Review",
        "Treatment Plans",
        "Appointments",
        "Consultation (SOAP)",
        "Vitals Capture",
        "Risk Management",
        "Patient Charts",
    ], 5.55),
    ("COACH", PURPLE, [
        "Assigned Patients",
        "Coaching Sessions",
        "Weekly Plan View",
        "Patient Hub",
        "Risk Escalation",
        "Appointments",
    ], 7.85),
    ("MANAGER", ORANGE, [
        "Staff Assignments",
        "Staff Statistics",
        "KYC Review",
        "Audit Log",
        "Analytics",
        "Inventory View",
    ], 10.15),
]
for title, clr, mods, cx in staff_cols:
    add_rect(slide, cx, 1.15, 2.1, 0.4, fill=clr,
             text=title, font_size=11, bold=True, radius=True)
    for i, m in enumerate(mods):
        add_rect(slide, cx, 1.65 + i * 0.53, 2.1, 0.45,
                 fill=WHITE, text=m, font_size=8.5, text_color=DARK_GRAY,
                 bold=False, border_color=clr, radius=True)

# Supabase / DB bar at bottom
add_rect(slide, 0.2, 6.9, 12.93, 0.42, fill=NAVY,
         text="SUPABASE (PostgreSQL) — Auth · Database · Storage · Realtime",
         font_size=10, bold=True, text_color=GOLD, radius=True)


# ═══════════════════════════════════════════════════════════════════════════
#  SLIDE 3 — KYC FLOW
# ═══════════════════════════════════════════════════════════════════════════
slide = prs.slides.add_slide(BLANK)
bg = slide.shapes.add_shape(1, 0, 0, W, H)
bg.fill.solid()
bg.fill.fore_color.rgb = LIGHT_GRAY
bg.line.fill.background()

slide_header(slide, "KYC FLOW — Know Your Customer",
             "Patient submits KYC → Staff reviews → Approve / Reject → Access granted", bg=TEAL)

# Swimlane labels
add_rect(slide, 0.1, 1.1, 1.3, 5.9, fill=GREEN,
         text="P A T I E N T", font_size=11, bold=True,
         text_color=WHITE, radius=True)
add_rect(slide, 1.5, 1.1, 1.3, 5.9, fill=TEAL,
         text="S T A F F\n(Admin/Doctor)", font_size=10, bold=True,
         text_color=WHITE, radius=True)

# Row 1 — Patient fills KYC
y = 1.2
flow_box(slide, 2.95, y, 2.0, 0.55, "1. Patient Registers\n(Email + Password)", fill=GREEN)
right_arrow(slide, 5.05, y + 0.18)
flow_box(slide, 5.35, y, 2.0, 0.55, "2. Auto-redirect to\nKYC Form", fill=GREEN_LT)
right_arrow(slide, 7.45, y + 0.18)
flow_box(slide, 7.75, y, 2.5, 0.55, "3. Fill KYC Details\n(IC, Name, Address,\nPhone, Medical, Emergency)", fill=GREEN_LT)
right_arrow(slide, 10.35, y + 0.18)
flow_box(slide, 10.65, y, 2.45, 0.55, "4. Submit KYC\n→ Status: PENDING", fill=GOLD,
         fs=9.5)

# Down arrow (patient lane to staff lane)
down_arrow(slide, 11.5, 1.85, color=TEAL)

# Row 2 — staff review
y2 = 2.2
flow_box(slide, 2.95, y2, 2.0, 0.55, "5. Notification sent\nto Admin/Doctor", fill=TEAL)
right_arrow(slide, 5.05, y2 + 0.18)
flow_box(slide, 5.35, y2, 2.0, 0.55, "6. Staff opens\nKYC List", fill=TEAL)
right_arrow(slide, 7.45, y2 + 0.18)
flow_box(slide, 7.75, y2, 2.5, 0.55, "7. Review KYC Details\n(IC, Address, Medical,\nEmergency Contact)", fill=NAVY_MED)
right_arrow(slide, 10.35, y2 + 0.18)

# Decision diamond
decision_box(slide, 10.65, y2 + 0.0, "8. APPROVE\nor REJECT?", fill=GOLD)

# Approve branch (down)
down_arrow(slide, 11.35, 2.9, color=GREEN)
flow_box(slide, 10.65, 3.2, 1.5, 0.55, "APPROVE\n✓ Status: Approved", fill=GREEN)
down_arrow(slide, 11.35, 3.83, color=GREEN)
flow_box(slide, 10.65, 4.1, 1.5, 0.55, "Notification to\nPatient", fill=GREEN_LT)
down_arrow(slide, 11.35, 4.73, color=GREEN)
flow_box(slide, 10.65, 5.0, 1.5, 0.55, "Patient Access\nGRANTED ✓", fill=GREEN)

# Reject branch (right-down from diamond)
add_text(slide, 12.2, 2.3, 0.9, 0.3, "Reject", font_size=9,
         color=RED, bold=True)
flow_box(slide, 12.25, 2.2, 0.95, 0.55, "REJECT\n✗ With Notes", fill=RED)
down_arrow(slide, 12.65, 2.83, color=RED)
flow_box(slide, 12.25, 3.1, 0.95, 0.55, "Notif to\nPatient", fill=RED_LT)
down_arrow(slide, 12.65, 3.73, color=RED)
flow_box(slide, 12.25, 4.0, 0.95, 0.55, "Patient can\nResubmit", fill=ORANGE)

# Notes row
y3 = 5.7
add_rect(slide, 0.1, y3, 13.13, 1.55, fill=WHITE,
         text="", border_color=TEAL, radius=True)
add_text(slide, 0.25, y3 + 0.05, 12.8, 1.4,
         "KEY RULES:\n"
         "• Self-registered patients → MUST have KYC approved before accessing Package, Plan, Library, Coaching\n"
         "• Staff-created patients → auto-approved (pre-vetted)\n"
         "• KYC submission stored in: psy_kyc_submissions  |  Status: pending / approved / rejected\n"
         "• Patient record (psy_patients) updated with KYC data upon approval  |  Export to Excel / Print available",
         font_size=9, color=DARK_GRAY)


# ═══════════════════════════════════════════════════════════════════════════
#  SLIDE 4 — PATIENT ONBOARDING FLOW
# ═══════════════════════════════════════════════════════════════════════════
slide = prs.slides.add_slide(BLANK)
bg = slide.shapes.add_shape(1, 0, 0, W, H)
bg.fill.solid()
bg.fill.fore_color.rgb = LIGHT_GRAY
bg.line.fill.background()

slide_header(slide, "PATIENT ONBOARDING FLOW",
             "From first login to full system access — 4 gates must be passed", bg=GREEN)

steps = [
    ("1", "Patient\nVisits App", GREEN, 0.3, 2.5),
    ("2", "Login /\nRegister", GREEN, 1.85, 2.5),
    ("3", "Auto-create\npsy_patients\nRecord + MRN", GREEN_LT, 3.4, 2.5),
    ("4", "KYC Form\n(Fill Details)", TEAL, 5.1, 2.5),
    ("5", "Staff Approves\nKYC", TEAL, 6.8, 2.5),
    ("6", "Select &\nPurchase\nPackage", GOLD, 8.5, 2.5),
    ("7", "Treatment\nPlan Auto-\nCreated", PURPLE, 10.2, 2.5),
    ("8", "Full Access\nUnlocked ✓", GREEN, 11.9, 2.5),
]

for num, label, clr, x, y in steps:
    add_rect(slide, x, y, 1.45, 0.85, fill=clr, text=label,
             font_size=9, text_color=WHITE, bold=True, radius=True)
    if x < 11.9:
        right_arrow(slide, x + 1.45, y + 0.3, color=MED_GRAY)

# Gate labels below
gates = [
    (3.4, "GATE 1:\nAuth"),
    (5.1, "GATE 2:\nKYC"),
    (6.8, "GATE 3:\nPackage"),
    (10.2, "GATE 4:\nPlan"),
]
for gx, glabel in gates:
    add_rect(slide, gx, 3.5, 1.45, 0.55, fill=RED_LT,
             text=glabel, font_size=8.5, text_color=WHITE, radius=True)

# Access locked/unlocked states
add_rect(slide, 0.3, 4.3, 5.5, 0.55, fill=RED,
         text="🔒 LOCKED — No access to Plan, Coaching, Library, Shop",
         font_size=9.5, text_color=WHITE, radius=True)
add_rect(slide, 5.85, 4.3, 7.2, 0.55, fill=GREEN,
         text="✅ UNLOCKED — Full access to all patient modules",
         font_size=9.5, text_color=WHITE, radius=True)

# Feature access table
headers = ["Module", "Auth", "KYC OK", "Package Active"]
cols_w = [3.5, 1.5, 1.5, 2.0]
table_x = [0.3, 3.8, 5.3, 6.8]
y_base = 5.1
add_rect(slide, 0.3, y_base, 8.85, 0.4, fill=NAVY,
         text="", radius=False)
for i, (h, tx) in enumerate(zip(headers, table_x)):
    add_text(slide, tx + 0.05, y_base + 0.05, cols_w[i], 0.35,
             h, font_size=9.5, color=WHITE, bold=True)

rows = [
    ("Dashboard", "✓", "-", "-"),
    ("KYC Form", "✓", "-", "-"),
    ("Package / Shop", "✓", "✓", "-"),
    ("Treatment Plan", "✓", "✓", "✓"),
    ("Coaching Library", "✓", "✓", "✓"),
    ("Daily Check-in", "✓", "✓", "✓"),
]
for ri, row in enumerate(rows):
    bg_clr = WHITE if ri % 2 == 0 else LIGHT_GRAY
    add_rect(slide, 0.3, y_base + 0.4 + ri * 0.33, 8.85, 0.32,
             fill=bg_clr, text="", radius=False, border_color=MED_GRAY)
    for ci, (val, tx) in enumerate(zip(row, table_x)):
        clr = GREEN if val == "✓" else (RED if val == "✗" else MED_GRAY)
        add_text(slide, tx + 0.05, y_base + 0.43 + ri * 0.33, cols_w[ci], 0.28,
                 val, font_size=9, color=clr, bold=(val == "✓"))


# ═══════════════════════════════════════════════════════════════════════════
#  SLIDE 5 — PACKAGE PURCHASE & PLAN ACTIVATION
# ═══════════════════════════════════════════════════════════════════════════
slide = prs.slides.add_slide(BLANK)
bg = slide.shapes.add_shape(1, 0, 0, W, H)
bg.fill.solid()
bg.fill.fore_color.rgb = LIGHT_GRAY
bg.line.fill.background()

slide_header(slide, "PACKAGE PURCHASE & PLAN ACTIVATION FLOW",
             "Patient selects a treatment package → payment → plan auto-created → access unlocked", bg=GOLD)

# Main horizontal flow
steps_pkg = [
    ("Patient opens\nPackej Page", TEAL, 0.3, 2.0),
    ("Browse Active\nPackages\n(Price, Duration,\nBenefits)", TEAL, 2.1, 2.0),
    ("Click\n'Buy Package'", GREEN, 3.9, 2.0),
    ("Package Detail\nPage\n(Full Info +\nPayment Form)", GREEN, 5.7, 2.0),
    ("Fill Payment\nDetails", GOLD, 7.5, 2.0),
    ("Payment\nProcessed\n✓", GREEN, 9.3, 2.0),
    ("psy_package_\npurchases\nRecord Created", PURPLE, 11.1, 2.0),
]

for i, (lbl, clr, x, y) in enumerate(steps_pkg):
    add_rect(slide, x, y, 1.65, 0.9, fill=clr, text=lbl,
             font_size=8.5, text_color=WHITE, bold=True, radius=True)
    if i < len(steps_pkg) - 1:
        right_arrow(slide, x + 1.65, y + 0.35, color=MED_GRAY)

# After purchase
down_arrow(slide, 11.9, 2.95, color=PURPLE)
add_rect(slide, 10.5, 3.25, 2.7, 0.65, fill=PURPLE,
         text="Auto-create Treatment Plan\n(psy_treatment_plans)\nDuration = Package weeks",
         font_size=9, text_color=WHITE, radius=True)

# Left arrow from plan to coach assignment
add_text(slide, 9.35, 3.45, 1.1, 0.3, "◀ assign", font_size=9,
         color=TEAL, bold=True)
add_rect(slide, 7.7, 3.25, 1.6, 0.65, fill=TEAL,
         text="Manager assigns\nCoach to Patient\n(psy_assignments)",
         font_size=8.5, text_color=WHITE, radius=True)

# Full access box
add_rect(slide, 0.3, 3.25, 7.3, 0.65, fill=GREEN,
         text="✅  Full Access Unlocked  —  Treatment Plan  •  Coaching  •  Library  •  Daily Check-in",
         font_size=10, text_color=WHITE, bold=True, radius=True)

# Package lifecycle
add_text(slide, 0.3, 4.2, 12.73, 0.3, "PACKAGE LIFECYCLE", font_size=11,
         color=NAVY, bold=True)

lifecycle = [
    ("PURCHASED", GOLD, 0.3, 4.6),
    ("ACTIVE\n(Access open)", GREEN, 2.3, 4.6),
    ("NEAR EXPIRY\n(Warning shown)", ORANGE, 4.5, 4.6),
    ("EXPIRED\n(Access locked)", RED, 6.7, 4.6),
    ("Patient selects\nnew Package", TEAL, 8.9, 4.6),
    ("Purchase again\n→ Re-activate", GREEN, 11.1, 4.6),
]
for i, (lbl, clr, x, y) in enumerate(lifecycle):
    add_rect(slide, x, y, 1.85, 0.65, fill=clr, text=lbl,
             font_size=8.5, text_color=WHITE, bold=True, radius=True)
    if i < len(lifecycle) - 1:
        right_arrow(slide, x + 1.85, y + 0.2, color=MED_GRAY)

# DB tables
add_rect(slide, 0.3, 5.6, 12.73, 0.55, fill=NAVY,
         text="DATABASE TABLES:  psy_packages (definitions)  •  psy_package_purchases (patient subscriptions + expiry)  •  psy_treatment_plans (auto-created)  •  psy_payments",
         font_size=9, text_color=GOLD, radius=True)

# Key rules
add_rect(slide, 0.3, 6.3, 12.73, 0.95, fill=WHITE,
         text="", border_color=GOLD, radius=True)
add_text(slide, 0.45, 6.35, 12.4, 0.85,
         "KEY RULES:\n"
         "• Patients MUST have an active, non-expired package to access Treatment Plan, Coaching, and Library.\n"
         "• Without active package → 'Package Required' lock screen with CTA to select package.\n"
         "• package_expires_at tracked per purchase — expiry auto-enforced on each page load.",
         font_size=9, color=DARK_GRAY)


# ═══════════════════════════════════════════════════════════════════════════
#  SLIDE 6 — TREATMENT SESSION LIFECYCLE
# ═══════════════════════════════════════════════════════════════════════════
slide = prs.slides.add_slide(BLANK)
bg = slide.shapes.add_shape(1, 0, 0, W, H)
bg.fill.solid()
bg.fill.fore_color.rgb = LIGHT_GRAY
bg.line.fill.background()

slide_header(slide, "TREATMENT SESSION LIFECYCLE",
             "From appointment booking to session completion, coaching notes & risk escalation", bg=PURPLE)

# Main flow
session_steps = [
    ("Doctor/Patient\nopens\nAppointments", TEAL, 0.3, 1.25),
    ("Doctor Books\nSession\n(Date, Time,\nWeek #)", NAVY_MED, 2.1, 1.25),
    ("psy_appointments\n+ psy_plan_weekly\n_progress created\nStatus: BOOKED", PURPLE, 3.9, 1.25),
    ("Notification\nsent to Patient\n📅", TEAL, 5.8, 1.25),
    ("Patient logs\nDaily Check-in\nbefore session\n(Optional)", GREEN, 7.6, 1.25),
    ("SESSION\nOCCURS\n(Google Meet\nor In-person)", GOLD, 9.4, 1.25),
    ("Coach fills\nCoaching.html\npost-session", PURPLE, 11.2, 1.25),
]
for i, (lbl, clr, x, y) in enumerate(session_steps):
    add_rect(slide, x, y, 1.7, 0.95, fill=clr, text=lbl,
             font_size=8.5, text_color=WHITE if clr != GOLD else DARK_GRAY,
             bold=True, radius=True)
    if i < len(session_steps) - 1:
        right_arrow(slide, x + 1.7, y + 0.37, color=MED_GRAY)

# Session status flow
down_arrow(slide, 12.0, 2.25, color=PURPLE)

add_text(slide, 0.3, 2.4, 12.73, 0.3, "SESSION STATUS TRANSITIONS", font_size=10,
         color=NAVY, bold=True)

statuses = [
    ("BOOKED", TEAL),
    ("HADIR\n(Attended)", GREEN),
    ("CANCELLED", RED),
    ("RESCHEDULED", ORANGE),
]
for i, (s, c) in enumerate(statuses):
    add_rect(slide, 0.3 + i * 2.1, 2.75, 1.8, 0.55, fill=c,
             text=s, font_size=9.5, text_color=WHITE, bold=True, radius=True)
    if i < len(statuses) - 1:
        right_arrow(slide, 0.3 + i * 2.1 + 1.8, 2.97, color=MED_GRAY)

# Booking rules box
add_rect(slide, 8.7, 2.75, 4.4, 0.55, fill=NAVY,
         text="BOOKING RULES:  Closed Mon & Tue  |  Slots: 8:30, 10:00, 14:00, 15:30\n"
              "Reschedule requires 1-2 days advance notice",
         font_size=8.5, text_color=GOLD, radius=True)

# After session flow (coaching notes)
add_text(slide, 0.3, 3.5, 12.73, 0.3, "POST-SESSION: COACHING NOTES & RISK ESCALATION", font_size=10,
         color=NAVY, bold=True)

coaching_steps = [
    ("Select Patient\n& Session Date", PURPLE, 0.3, 3.85),
    ("Record Coaching\n• Pillar Focus\n• Mood Pre/Post\n• Notes & Goals\n• Homework", PURPLE, 2.2, 3.85),
    ("Status:\nCompleted", GREEN, 4.1, 3.85),
    ("OR\nEscalate Risk?", GOLD, 5.8, 3.85),
    ("Create Risk\nAlert\n(HIGH/CRITICAL)", RED, 7.7, 3.85),
    ("psy_coaching\n_sessions\nRecord Saved", NAVY_MED, 9.6, 3.85),
    ("Patient views\nSession History\non Plan.html", TEAL, 11.5, 3.85),
]
for i, (lbl, clr, x, y) in enumerate(coaching_steps):
    add_rect(slide, x, y, 1.7, 0.95, fill=clr, text=lbl,
             font_size=8, text_color=WHITE if clr != GOLD else DARK_GRAY,
             bold=True, radius=True)
    if i < len(coaching_steps) - 1:
        right_arrow(slide, x + 1.7, y + 0.37, color=MED_GRAY)

# Clinic hours & DB
add_rect(slide, 0.3, 5.05, 12.73, 0.45, fill=NAVY,
         text="DATABASE:  psy_appointments  •  psy_plan_weekly_progress (status, score, meet_link, notes)  •  psy_coaching_sessions  •  psy_risk_alerts",
         font_size=9, text_color=GOLD, radius=True)

# BPS-S pillars
add_rect(slide, 0.3, 5.6, 12.73, 0.8, fill=WHITE,
         text="", border_color=PURPLE, radius=True)
add_text(slide, 0.45, 5.65, 12.4, 0.7,
         "BPS-S TREATMENT PILLARS (coaching & plan structured around 4 pillars):\n"
         "🔵 BIOLOGICAL — physical health goals (sleep, exercise, medication compliance)\n"
         "🟣 PSYCHO — psychological goals (CBT homework, mood tracking, thought records)\n"
         "🟢 SOCIAL — social engagement goals (relationships, community activities)\n"
         "🟡 SPIRITUAL — spiritual practices (solat, zikir, Quran reading, breathing)",
         font_size=8.5, color=DARK_GRAY)


# ═══════════════════════════════════════════════════════════════════════════
#  SLIDE 7 — RISK ESCALATION & SLA FLOW
# ═══════════════════════════════════════════════════════════════════════════
slide = prs.slides.add_slide(BLANK)
bg = slide.shapes.add_shape(1, 0, 0, W, H)
bg.fill.solid()
bg.fill.fore_color.rgb = LIGHT_GRAY
bg.line.fill.background()

slide_header(slide, "RISK ESCALATION & SLA MONITORING FLOW",
             "Clinical risk alerts with 15-minute SLA for HIGH/CRITICAL severity", bg=RED)

# Severity legend
sev = [("CRITICAL", RED, 0.3), ("HIGH", ORANGE, 2.0), ("MEDIUM", GOLD, 3.7)]
for lbl, clr, x in sev:
    add_rect(slide, x, 1.15, 1.5, 0.4, fill=clr,
             text=lbl, font_size=10, bold=True, text_color=WHITE if clr != GOLD else DARK_GRAY,
             radius=True)

# Categories
cats = ["Mental Health Crisis", "Medication Non-compliance", "Non-attendance", "Clinical Escalation"]
for i, c in enumerate(cats):
    add_chip(slide, 5.5 + i * 2.0, 1.15, 1.85, 0.4, c, fill=NAVY_MED, fs=8.5)

# Main risk flow (vertical swimlanes)
lanes = [
    ("TRIGGER\nSource", TEAL, 0.3, 1.8),
    ("Risk Alert\nCreated\n(psy_risk_alerts)", RED, 2.2, 1.8),
    ("Status:\nOPEN 🔴", RED_LT, 4.1, 1.8),
    ("SLA Timer\nStarts\n⏱ 15 min", ORANGE, 6.0, 1.8),
    ("Staff\nACKNOWLEDGES\nStatus: ACK 🟡", GOLD, 7.9, 1.8),
    ("Investigation\n& Intervention\nPeriod", NAVY_MED, 9.8, 1.8),
    ("Staff\nRESOLVES\nStatus: Done ✅", GREEN, 11.7, 1.8),
]
for i, (lbl, clr, x, y) in enumerate(lanes):
    add_rect(slide, x, y, 1.7, 0.85, fill=clr, text=lbl,
             font_size=8.5, text_color=WHITE if clr not in (GOLD,) else DARK_GRAY,
             bold=True, radius=True)
    if i < len(lanes) - 1:
        right_arrow(slide, x + 1.7, y + 0.32, color=MED_GRAY)

# Trigger sources
trigger_sources = [
    ("Coach marks\n'Escalate Risk'\nin coaching session", PURPLE),
    ("Doctor flags\nrisk in consultation", TEAL),
    ("Patient self-\nreports crisis\n(Issue form)", GREEN),
    ("System: Patient\nmissed 2+ sessions", NAVY_MED),
]
for i, (src, clr) in enumerate(trigger_sources):
    add_rect(slide, 0.3 + i * 2.2, 2.85, 2.0, 0.7, fill=clr,
             text=src, font_size=8, text_color=WHITE, radius=True)
    up_y = 2.85
    # small arrow up
    add_text(slide, 0.3 + i * 2.2 + 0.85, 2.7, 0.3, 0.2, "▲",
             font_size=8, color=clr)

# SLA breach box
add_rect(slide, 0.3, 3.7, 13.03, 0.65, fill=RED,
         text="⚠  SLA BREACH  — If HIGH/CRITICAL not acknowledged within 15 minutes → Escalation alert sent to senior staff / manager",
         font_size=10, text_color=WHITE, bold=True, radius=True)

# Alert statuses table
add_text(slide, 0.3, 4.5, 12.73, 0.3, "RISK ALERT STATUS WORKFLOW", font_size=10,
         color=NAVY, bold=True)

status_rows = [
    ("OPEN", RED, "Alert created. No action taken yet. SLA timer running."),
    ("ACKNOWLEDGED", GOLD, "Staff confirmed awareness. Investigation underway. SLA paused."),
    ("RESOLVED", GREEN, "Risk mitigated. Resolution notes logged. All actions in audit log."),
]
for i, (status, clr, desc) in enumerate(status_rows):
    add_rect(slide, 0.3, 4.85 + i * 0.52, 2.0, 0.45, fill=clr,
             text=status, font_size=10, bold=True,
             text_color=WHITE if clr != GOLD else DARK_GRAY, radius=True)
    add_text(slide, 2.4, 4.88 + i * 0.52, 10.8, 0.42,
             desc, font_size=9.5, color=DARK_GRAY)

# DB + audit
add_rect(slide, 0.3, 6.45, 12.73, 0.45, fill=NAVY,
         text="DATABASE:  psy_risk_alerts (patient_id, severity, category, description, status, created_by, acknowledged_by, resolved_at)  •  psy_audit_log (all actions logged)",
         font_size=9, text_color=GOLD, radius=True)


# ═══════════════════════════════════════════════════════════════════════════
#  SLIDE 8 — DAILY CHECK-IN FLOW
# ═══════════════════════════════════════════════════════════════════════════
slide = prs.slides.add_slide(BLANK)
bg = slide.shapes.add_shape(1, 0, 0, W, H)
bg.fill.solid()
bg.fill.fore_color.rgb = LIGHT_GRAY
bg.line.fill.background()

slide_header(slide, "DAILY CHECK-IN & MOOD TRACKING FLOW",
             "Patient logs daily health data → visualised on dashboard → reviewed by coach", bg=GREEN)

# Patient flow
p_steps = [
    ("Patient opens\nDashboard", GREEN, 0.3, 1.25),
    ("Sees 'Check-in\nToday' CTA", GREEN, 2.0, 1.25),
    ("Opens\ncheckin.html", GREEN, 3.7, 1.25),
    ("Fill Mood Score\n(1-10) 😊", TEAL, 5.4, 1.25),
    ("Fill Energy Level\n(1-10)", TEAL, 7.1, 1.25),
    ("Sleep: Hours\n+ Quality", TEAL, 8.8, 1.25),
    ("Symptoms\n(multi-select)", NAVY_MED, 10.5, 1.25),
    ("Activities &\nNotes\n(submit)", NAVY_MED, 12.2, 1.25),
]
for i, (lbl, clr, x, y) in enumerate(p_steps):
    add_rect(slide, x, y, 1.6, 0.8, fill=clr, text=lbl,
             font_size=8.5, text_color=WHITE, bold=True, radius=True)
    if i < len(p_steps) - 1:
        right_arrow(slide, x + 1.6, y + 0.29, color=MED_GRAY)

# After submit
down_arrow(slide, 12.95, 2.1, color=PURPLE)

save_steps = [
    ("psy_daily_\ncheckins Record\nSaved", PURPLE, 11.5, 2.4),
    ("Dashboard\nUpdates:\nToday's Mood", TEAL, 9.6, 2.4),
    ("7-day Mood\nHistory Chart\nUpdates", GREEN, 7.7, 2.4),
    ("Coach reviews\non Patient Hub\n(coach view)", PURPLE, 5.8, 2.4),
    ("Risk trigger:\nMood < 3 for\n2 days → Alert", RED, 3.9, 2.4),
]
for i, (lbl, clr, x, y) in enumerate(save_steps):
    add_rect(slide, x, y, 1.7, 0.8, fill=clr, text=lbl,
             font_size=8, text_color=WHITE, bold=True, radius=True)
    if i < len(save_steps) - 1:
        add_text(slide, x - 0.25, y + 0.28, 0.3, 0.3, "◀",
                 font_size=9, color=MED_GRAY)

# Symptoms & activities detail
add_text(slide, 0.3, 3.4, 6.2, 0.3, "SYMPTOMS (Multi-select)", font_size=10,
         color=NAVY, bold=True)
symptoms = ["Headache", "Dizziness", "Anxiety", "Mood Swings", "Insomnia",
            "Fatigue", "Chest Pain", "Loss of Appetite"]
for i, s in enumerate(symptoms):
    col = i % 4
    row = i // 4
    add_chip(slide, 0.3 + col * 1.55, 3.75 + row * 0.42, 1.45, 0.35,
             s, fill=NAVY_MED, fs=8.5)

add_text(slide, 6.9, 3.4, 6.2, 0.3, "ACTIVITIES / PRACTICES (Multi-select)", font_size=10,
         color=GREEN, bold=True)
activities = ["Zikir", "Solat", "Exercise", "Healthy Diet",
              "Breathing", "Quran", "Social Activity", "Journaling"]
for i, a in enumerate(activities):
    col = i % 4
    row = i // 4
    add_chip(slide, 6.9 + col * 1.55, 3.75 + row * 0.42, 1.45, 0.35,
             a, fill=GREEN, fs=8.5)

# DB
add_rect(slide, 0.3, 4.7, 12.73, 0.45, fill=NAVY,
         text="DATABASE:  psy_daily_checkins (mood_score, energy_score, sleep_hours, sleep_quality, symptoms[], activities[], notes, checkin_date)  •  psy_plan_check_ins",
         font_size=9, text_color=GOLD, radius=True)

add_rect(slide, 0.3, 5.25, 12.73, 0.65, fill=WHITE,
         text="", border_color=GREEN, radius=True)
add_text(slide, 0.45, 5.3, 12.4, 0.6,
         "VISUALISATION ON DASHBOARD:\n"
         "• Today's mood emoji card (color-coded: green ≥7, amber 4-6, red ≤3)\n"
         "• 7-day mood history bar chart  •  Weekly energy trend  •  Sleep quality indicator  •  Attendance/compliance summary",
         font_size=9, color=DARK_GRAY)


# ═══════════════════════════════════════════════════════════════════════════
#  SLIDE 9 — INVENTORY REQUEST & APPROVAL FLOW
# ═══════════════════════════════════════════════════════════════════════════
slide = prs.slides.add_slide(BLANK)
bg = slide.shapes.add_shape(1, 0, 0, W, H)
bg.fill.solid()
bg.fill.fore_color.rgb = LIGHT_GRAY
bg.line.fill.background()

slide_header(slide, "INVENTORY MANAGEMENT & REQUEST APPROVAL FLOW",
             "Staff requests stock replenishment → Admin approves → Stock updated automatically", bg=ORANGE)

# Swimlane: Staff | Admin
add_rect(slide, 0.1, 1.1, 1.3, 5.7, fill=TEAL,
         text="S T A F F", font_size=11, bold=True, text_color=WHITE, radius=True)
add_rect(slide, 1.5, 1.1, 1.3, 5.7, fill=RED,
         text="A D M I N", font_size=11, bold=True, text_color=WHITE, radius=True)

# Staff lane steps
staff_inv = [
    ("Open\nInventory.html", TEAL, 2.95, 1.2),
    ("See Item List\n+ Stock Levels\n+ Low Stock ⚠", TEAL, 4.75, 1.2),
    ("Identify Low\nStock Item", ORANGE, 6.55, 1.2),
    ("Click 'Request\nStock' Button", ORANGE, 8.35, 1.2),
    ("Fill Request:\nQty + Unit Price", ORANGE, 10.15, 1.2),
    ("Submit\nRequest", GREEN, 11.95, 1.2),
]
for i, (lbl, clr, x, y) in enumerate(staff_inv):
    add_rect(slide, x, y, 1.65, 0.8, fill=clr, text=lbl,
             font_size=8.5, text_color=WHITE, bold=True, radius=True)
    if i < len(staff_inv) - 1:
        right_arrow(slide, x + 1.65, y + 0.29, color=MED_GRAY)

# Down to admin
down_arrow(slide, 12.75, 2.05, color=MED_GRAY)

# psy_inventory_requests record
flow_box(slide, 11.2, 2.35, 1.9, 0.65,
         "psy_inventory_requests\nCreated\nStatus: PENDING", fill=PURPLE)

# Admin lane
admin_inv = [
    ("Admin opens\nInventory.html", RED, 2.95, 3.2),
    ("Sees 'Pending\nRequests'\nSection", RED, 4.75, 3.2),
    ("Reviews Request\n(Item, Qty, Cost,\nRequested by)", NAVY_MED, 6.55, 3.2),
    ("Decision:\nAPPROVE or\nREJECT?", GOLD, 8.35, 3.2),
]
for i, (lbl, clr, x, y) in enumerate(admin_inv):
    add_rect(slide, x, y, 1.65, 0.8, fill=clr, text=lbl,
             font_size=8.5,
             text_color=WHITE if clr != GOLD else DARK_GRAY,
             bold=True, radius=True)
    if i < len(admin_inv) - 1:
        right_arrow(slide, x + 1.65, y + 0.29, color=MED_GRAY)

# Approve path
flow_box(slide, 10.15, 3.2, 1.65, 0.8, "APPROVE ✓\nStatus:\nApproved", fill=GREEN)
right_arrow(slide, 11.8, 3.54, color=GREEN)
flow_box(slide, 12.05, 3.2, 1.2, 0.8, "Stock Updated\n+= Qty", fill=GREEN)

# Reject path
down_arrow(slide, 9.15, 4.05, color=RED)
flow_box(slide, 8.35, 4.4, 1.65, 0.65, "REJECT ✗\nWith Reason", fill=RED)
right_arrow(slide, 10.0, 4.7, color=RED)
flow_box(slide, 10.25, 4.4, 1.65, 0.65, "Notification\nto Staff", fill=RED_LT)

# Dashboard cards
add_text(slide, 2.95, 5.25, 10.0, 0.3, "DASHBOARD STATS (live)", font_size=10,
         color=NAVY, bold=True)
cards = [
    ("Total Items\nin Stock", TEAL),
    ("Low Stock\nAlerts ⚠", ORANGE),
    ("Pending\nApprovals", GOLD),
    ("Items Below\nMin Threshold", RED),
]
for i, (lbl, clr) in enumerate(cards):
    add_rect(slide, 2.95 + i * 2.4, 5.6, 2.2, 0.65, fill=clr,
             text=lbl, font_size=9.5, text_color=WHITE if clr != GOLD else DARK_GRAY,
             bold=True, radius=True)

add_rect(slide, 2.95, 6.4, 10.3, 0.4, fill=NAVY,
         text="DATABASE:  psy_inventory_items (name, category, current_stock, min_stock, unit_price)  •  psy_inventory_requests (status: pending/approved/rejected)",
         font_size=9, text_color=GOLD, radius=True)


# ═══════════════════════════════════════════════════════════════════════════
#  SLIDE 10 — ORDER PROCESSING & DELIVERY FLOW
# ═══════════════════════════════════════════════════════════════════════════
slide = prs.slides.add_slide(BLANK)
bg = slide.shapes.add_shape(1, 0, 0, W, H)
bg.fill.solid()
bg.fill.fore_color.rgb = LIGHT_GRAY
bg.line.fill.background()

slide_header(slide, "E-COMMERCE: ORDER PROCESSING & DELIVERY FLOW",
             "Patient shops → checkout → staff fulfils → delivery tracked → patient confirms receipt", bg=TEAL)

# Swimlane Patient | Staff
add_rect(slide, 0.1, 1.1, 1.3, 5.5, fill=GREEN,
         text="P A T I E N T", font_size=10, bold=True, text_color=WHITE, radius=True)
add_rect(slide, 1.5, 1.1, 1.3, 5.5, fill=TEAL,
         text="S T A F F /\nA D M I N", font_size=9, bold=True, text_color=WHITE, radius=True)

# Patient flow (top row)
patient_order = [
    ("Browse Products\n(shop.html)", GREEN, 2.95, 1.2),
    ("Add to Cart\n🛒 (localStorage)", GREEN, 4.65, 1.2),
    ("Cart FAB shows\nitem count", GREEN, 6.35, 1.2),
    ("Payment.html\n(Fill billing,\nselect method)", GOLD, 8.05, 1.2),
    ("Submit Order\n→ Confirmation", GREEN, 9.75, 1.2),
    ("psy_orders\nCreated\nStatus: ORDERED", PURPLE, 11.45, 1.2),
]
for i, (lbl, clr, x, y) in enumerate(patient_order):
    add_rect(slide, x, y, 1.6, 0.8, fill=clr, text=lbl,
             font_size=8, text_color=WHITE if clr != GOLD else DARK_GRAY,
             bold=True, radius=True)
    if i < len(patient_order) - 1:
        right_arrow(slide, x + 1.6, y + 0.29, color=MED_GRAY)

# Staff flow (bottom row)
down_arrow(slide, 12.2, 2.05, color=TEAL)
staff_order = [
    ("Admin views\nOrders List", TEAL, 11.45, 2.4),
    ("Picks & Packs\nOrder", TEAL, 9.75, 2.4),
    ("Ships /\nDelivers", TEAL, 8.05, 2.4),
    ("Updates status:\nIN DELIVERY", ORANGE, 6.35, 2.4),
    ("Notification\nto Patient 📱", GREEN, 4.65, 2.4),
]
for i, (lbl, clr, x, y) in enumerate(staff_order):
    add_rect(slide, x, y, 1.6, 0.8, fill=clr, text=lbl,
             font_size=8, text_color=WHITE, bold=True, radius=True)
    if i < len(staff_order) - 1:
        add_text(slide, x - 0.25, y + 0.29, 0.3, 0.3, "◀",
                 font_size=9, color=MED_GRAY)

# Patient confirms delivery
down_arrow(slide, 5.4, 3.25, color=GREEN)
patient_confirm = [
    ("Patient opens\norders.html", GREEN, 2.95, 3.6),
    ("Views order\nstatus", GREEN, 4.65, 3.6),
    ("Marks as\nRECEIVED ✓", GREEN, 6.35, 3.6),
    ("Status:\nDELIVERED\n+ delivered_at", GREEN, 8.05, 3.6),
    ("Notification:\nOrder Complete", TEAL, 9.75, 3.6),
]
for i, (lbl, clr, x, y) in enumerate(patient_confirm):
    add_rect(slide, x, y, 1.6, 0.75, fill=clr, text=lbl,
             font_size=8, text_color=WHITE, bold=True, radius=True)
    if i < len(patient_confirm) - 1:
        right_arrow(slide, x + 1.6, y + 0.27, color=MED_GRAY)

# Order status lifecycle
add_text(slide, 2.95, 4.55, 10.0, 0.3, "ORDER STATUS LIFECYCLE", font_size=10,
         color=NAVY, bold=True)
order_statuses = [
    ("ORDERED\n🟡 Pending", GOLD),
    ("IN DELIVERY\n📦 Shipped", ORANGE),
    ("DELIVERED\n✅ Complete", GREEN),
    ("CANCELLED\n❌", RED),
]
for i, (lbl, clr) in enumerate(order_statuses):
    add_rect(slide, 2.95 + i * 2.55, 4.9, 2.3, 0.6, fill=clr,
             text=lbl, font_size=9.5,
             text_color=WHITE if clr not in (GOLD,) else DARK_GRAY,
             bold=True, radius=True)
    if i < len(order_statuses) - 1:
        right_arrow(slide, 2.95 + i * 2.55 + 2.3, 5.14, color=MED_GRAY)

add_rect(slide, 2.95, 5.65, 10.3, 0.4, fill=NAVY,
         text="DATABASE:  psy_products  •  psy_orders (patient_id, status, items[], total_price, delivery_address, delivered_at)  •  psy_payments (method, transaction_id)",
         font_size=9, text_color=GOLD, radius=True)


# ═══════════════════════════════════════════════════════════════════════════
#  SLIDE 11 — SOAP CONSULTATION & VITALS FLOW
# ═══════════════════════════════════════════════════════════════════════════
slide = prs.slides.add_slide(BLANK)
bg = slide.shapes.add_shape(1, 0, 0, W, H)
bg.fill.solid()
bg.fill.fore_color.rgb = LIGHT_GRAY
bg.line.fill.background()

slide_header(slide, "DOCTOR CONSULTATION (SOAP) & VITALS CAPTURE FLOW",
             "Doctor conducts clinical review, records SOAP notes and vital signs", bg=TEAL)

# SOAP tabs
soap_tabs = [
    ("S — Subjective", NAVY_MED,
     "• Chief Complaint (CC)\n• History of Present Illness (HPI)\n• Patient-reported symptoms\n• Duration & severity"),
    ("O — Objective", TEAL,
     "• Latest vital signs\n• Physical examination findings\n• Lab results\n• Observations"),
    ("A — Assessment", PURPLE,
     "• Diagnoses (ICD-10 codes)\n• Clinical reasoning\n• Differential diagnoses\n• Risk level assessment"),
    ("P — Plan", GREEN,
     "• Medications (Rx)\n• Lab orders\n• Follow-up timeline\n• Referrals\n• Patient instructions"),
]
for i, (title, clr, content) in enumerate(soap_tabs):
    add_rect(slide, 0.3 + i * 3.25, 1.15, 3.1, 0.45, fill=clr,
             text=title, font_size=11, bold=True, text_color=WHITE, radius=True)
    add_rect(slide, 0.3 + i * 3.25, 1.65, 3.1, 2.0, fill=WHITE,
             text="", border_color=clr, radius=True)
    add_text(slide, 0.45 + i * 3.25, 1.7, 2.85, 1.9,
             content, font_size=9, color=DARK_GRAY)

# Status & signing
status_row = [
    ("Save as DRAFT\n(Editable)", GOLD, 0.3, 3.85),
    ("Sign & Save\n(Finalises record)", GREEN, 2.8, 3.85),
    ("psy_soap_notes\nRecord Created\nstatus: draft/signed", PURPLE, 5.3, 3.85),
    ("Linked to\nPatient Chart\n(psy_patients)", NAVY_MED, 7.8, 3.85),
]
for i, (lbl, clr, x, y) in enumerate(status_row):
    add_rect(slide, x, y, 2.3, 0.75, fill=clr, text=lbl,
             font_size=9, text_color=WHITE if clr != GOLD else DARK_GRAY,
             bold=True, radius=True)
    if i < len(status_row) - 1:
        right_arrow(slide, x + 2.3, y + 0.27, color=MED_GRAY)

# Vitals section
add_text(slide, 0.3, 4.8, 12.73, 0.3, "VITALS CAPTURE FLOW (Doctor)", font_size=10,
         color=NAVY, bold=True)

vital_steps = [
    ("Open\nvitals.html", TEAL, 0.3, 5.15),
    ("Select Patient\n& Date", TEAL, 2.0, 5.15),
    ("Enter Vitals:\nBP, HR, Temp\nGlucose, Weight\nHeight", NAVY_MED, 3.7, 5.15),
    ("Add Notes", NAVY_MED, 5.65, 5.15),
    ("Save Vitals\n✓", GREEN, 7.35, 5.15),
    ("psy_vitals\nRecord Saved", PURPLE, 9.05, 5.15),
    ("Visible in SOAP\nObjective Tab\n& Patient Hub", TEAL, 10.75, 5.15),
]
for i, (lbl, clr, x, y) in enumerate(vital_steps):
    add_rect(slide, x, y, 1.55, 0.85, fill=clr, text=lbl,
             font_size=8.5, text_color=WHITE, bold=True, radius=True)
    if i < len(vital_steps) - 1:
        right_arrow(slide, x + 1.55, y + 0.3, color=MED_GRAY)

add_rect(slide, 0.3, 6.2, 12.73, 0.45, fill=NAVY,
         text="DATABASE:  psy_soap_notes (subjective, objective, assessment, plan, status: draft/signed, signed_at)  •  psy_vitals (bp_systolic, bp_diastolic, heart_rate, temperature, blood_glucose, weight, height)",
         font_size=9, text_color=GOLD, radius=True)


# ═══════════════════════════════════════════════════════════════════════════
#  SLIDE 12 — STAFF ROLE ACCESS CONTROL MATRIX
# ═══════════════════════════════════════════════════════════════════════════
slide = prs.slides.add_slide(BLANK)
bg = slide.shapes.add_shape(1, 0, 0, W, H)
bg.fill.solid()
bg.fill.fore_color.rgb = LIGHT_GRAY
bg.line.fill.background()

slide_header(slide, "STAFF ROLE-BASED ACCESS CONTROL (RBAC) MATRIX",
             "Which modules each staff role can access — enforced on every page load", bg=NAVY)

modules = [
    "Patient List",
    "KYC Review & Approve",
    "Treatment Plans",
    "Appointments / Schedule",
    "Consultation (SOAP)",
    "Vitals Capture",
    "Coaching Sessions",
    "Weekly Plan View",
    "Risk Management",
    "Staff Management",
    "Staff Assignments",
    "Staff Statistics",
    "Inventory Management",
    "Products & Packages",
    "Orders & Delivery",
    "Self-Help Library",
    "Announcements",
    "Audit Log",
]

roles_matrix = {
    "Admin":   [1,1,0,0,0,0,0,0,0,1,1,0,1,1,1,1,1,1],
    "Doctor":  [1,1,1,1,1,1,0,0,1,0,0,0,0,0,0,0,0,0],
    "Coach":   [1,0,0,1,0,0,1,1,1,0,0,0,0,0,0,0,0,0],
    "Manager": [1,1,1,1,0,0,0,0,0,0,1,1,1,0,1,0,1,1],
}

role_colors = {
    "Admin": RED, "Doctor": TEAL, "Coach": PURPLE, "Manager": ORANGE
}

# Header row
col_x = [4.0, 5.9, 7.8, 9.7]
role_names = ["Admin", "Doctor", "Coach", "Manager"]
for i, (rn, rx) in enumerate(zip(role_names, col_x)):
    add_rect(slide, rx, 1.15, 1.7, 0.4, fill=role_colors[rn],
             text=rn, font_size=10, bold=True, text_color=WHITE, radius=True)

for ri, mod in enumerate(modules):
    y_r = 1.62 + ri * 0.32
    bg_clr = WHITE if ri % 2 == 0 else LIGHT_GRAY
    add_rect(slide, 0.3, y_r, 3.6, 0.29, fill=bg_clr,
             text=mod, font_size=8.5, text_color=DARK_GRAY,
             bold=False, border_color=MED_GRAY, radius=False,
             align=PP_ALIGN.LEFT)
    for ci, rn in enumerate(role_names):
        val = roles_matrix[rn][ri]
        cell_fill = GREEN if val else LIGHT_GRAY
        cell_text = "✓" if val else "—"
        cell_color = WHITE if val else MED_GRAY
        add_rect(slide, col_x[ci], y_r, 1.7, 0.29,
                 fill=cell_fill, text=cell_text,
                 font_size=9, text_color=cell_color, bold=val,
                 border_color=MED_GRAY, radius=False)

# Legend
add_rect(slide, 11.6, 1.15, 1.5, 0.35, fill=GREEN,
         text="✓ Has Access", font_size=9, text_color=WHITE, radius=True)
add_rect(slide, 11.6, 1.6, 1.5, 0.35, fill=LIGHT_GRAY,
         text="— No Access", font_size=9, text_color=MED_GRAY, radius=True,
         border_color=MED_GRAY)

add_rect(slide, 11.6, 2.1, 1.5, 5.1, fill=WHITE,
         text="", border_color=NAVY, radius=True)
add_text(slide, 11.7, 2.15, 1.35, 5.0,
         "ACCESS\nCONTROL\nENFORCED:\n\n"
         "• On every\n  page load\n\n"
         "• Via check\n  Auth()\n\n"
         "• Redirects\n  to own\n  dashboard\n  if denied\n\n"
         "• psy_profiles\n  role +\n  staff_role\n  fields",
         font_size=8, color=DARK_GRAY)


# ═══════════════════════════════════════════════════════════════════════════
#  SLIDE 13 — COMPLETE SYSTEM FLOW SUMMARY
# ═══════════════════════════════════════════════════════════════════════════
slide = prs.slides.add_slide(BLANK)
bg = slide.shapes.add_shape(1, 0, 0, W, H)
bg.fill.solid()
bg.fill.fore_color.rgb = NAVY
bg.line.fill.background()

slide_header(slide, "COMPLETE SYSTEM FLOW — IBNU SINA WELLNESS",
             "End-to-end patient journey & staff operations", bg=GOLD)

# Patient journey (top lane)
add_rect(slide, 0.1, 1.1, 1.2, 5.5, fill=GREEN,
         text="PATIENT", font_size=10, bold=True, text_color=WHITE, radius=True)

patient_journey = [
    ("Register\n+ Login", GREEN),
    ("Fill KYC\nForm", TEAL),
    ("KYC\nApproved", GREEN),
    ("Select\nPackage", GOLD),
    ("Plan\nActivated", PURPLE),
    ("Book\nSession", NAVY_MED),
    ("Daily\nCheck-in", TEAL),
    ("Session\nOccurs", GREEN),
    ("View\nProgress", PURPLE),
    ("Feedback\n& Shop", GREEN),
]
for i, (lbl, clr) in enumerate(patient_journey):
    x = 1.45 + i * 1.18
    add_rect(slide, x, 1.2, 1.1, 0.75, fill=clr, text=lbl,
             font_size=8, text_color=WHITE if clr != GOLD else DARK_GRAY,
             bold=True, radius=True)
    if i < len(patient_journey) - 1:
        right_arrow(slide, x + 1.1, 1.5, color=WHITE)

# Admin lane
add_rect(slide, 0.1, 2.1, 1.2, 1.1, fill=RED,
         text="ADMIN", font_size=9, bold=True, text_color=WHITE, radius=True)
admin_j = [
    ("Create\nStaff", RED), ("Approve\nKYC", RED), ("Manage\nPackages", RED),
    ("Manage\nInventory", RED), ("View\nOrders", RED), ("Audit\nLog", RED),
]
for i, (lbl, clr) in enumerate(admin_j):
    add_rect(slide, 1.45 + i * 1.18, 2.2, 1.1, 0.65, fill=clr, text=lbl,
             font_size=8, text_color=WHITE, bold=True, radius=True)

# Doctor lane
add_rect(slide, 0.1, 3.1, 1.2, 1.1, fill=TEAL,
         text="DOCTOR", font_size=9, bold=True, text_color=WHITE, radius=True)
doc_j = [
    ("Review\nKYC", TEAL), ("Create\nPlan", TEAL), ("Book\nSessions", TEAL),
    ("SOAP\nNotes", TEAL), ("Vitals", TEAL), ("Risk\nMgmt", RED),
]
for i, (lbl, clr) in enumerate(doc_j):
    add_rect(slide, 1.45 + i * 1.18, 3.2, 1.1, 0.65, fill=clr, text=lbl,
             font_size=8, text_color=WHITE, bold=True, radius=True)

# Coach lane
add_rect(slide, 0.1, 4.1, 1.2, 1.1, fill=PURPLE,
         text="COACH", font_size=9, bold=True, text_color=WHITE, radius=True)
coach_j = [
    ("Assigned\nPatients", PURPLE), ("Patient\nHub", PURPLE),
    ("Coaching\nSession", PURPLE), ("Weekly\nPlan", PURPLE),
    ("Escalate\nRisk", RED), ("Notes &\nHomework", PURPLE),
]
for i, (lbl, clr) in enumerate(coach_j):
    add_rect(slide, 1.45 + i * 1.18, 4.2, 1.1, 0.65, fill=clr, text=lbl,
             font_size=8, text_color=WHITE, bold=True, radius=True)

# Manager lane
add_rect(slide, 0.1, 5.1, 1.2, 1.1, fill=ORANGE,
         text="MANAGER", font_size=8, bold=True, text_color=WHITE, radius=True)
mgr_j = [
    ("Assignments", ORANGE), ("Staff\nStats", ORANGE), ("Analytics", ORANGE),
    ("KYC\nReview", ORANGE), ("Inventory", ORANGE), ("Audit Log", ORANGE),
]
for i, (lbl, clr) in enumerate(mgr_j):
    add_rect(slide, 1.45 + i * 1.18, 5.2, 1.1, 0.65, fill=clr, text=lbl,
             font_size=8, text_color=WHITE, bold=True, radius=True)

# Supabase DB at bottom
add_rect(slide, 0.1, 6.35, 13.13, 0.95, fill=NAVY_MED,
         text="", border_color=GOLD, radius=True)
add_text(slide, 0.25, 6.4, 12.9, 0.85,
         "SUPABASE DATABASE LAYER — All data persisted to PostgreSQL via Supabase SDK\n"
         "psy_profiles  •  psy_patients  •  psy_kyc_submissions  •  psy_treatment_plans  •  psy_plan_weekly_progress\n"
         "psy_coaching_sessions  •  psy_soap_notes  •  psy_vitals  •  psy_packages  •  psy_package_purchases\n"
         "psy_products  •  psy_orders  •  psy_payments  •  psy_risk_alerts  •  psy_inventory_items  •  psy_audit_log",
         font_size=8.5, color=GOLD)


# ═══════════════════════════════════════════════════════════════════════════
#  SAVE
# ═══════════════════════════════════════════════════════════════════════════
output_path = r"c:\Users\ASUS\ISW system\ISW_System_Flow_Architecture.pptx"
prs.save(output_path)
print(f"PowerPoint saved: {output_path}")
print(f"Slides: {len(prs.slides)}")
