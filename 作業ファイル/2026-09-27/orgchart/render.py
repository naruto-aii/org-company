from PIL import Image, ImageDraw, ImageFont
S = 2
REG = "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc"
BLD = "/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc"
def jp(path, size):
    for i in range(10):
        f = ImageFont.truetype(path, size*S, index=i)
        if f.getname()[0].endswith("JP"): return f
    return ImageFont.truetype(path, size*S)

COL = {  # fill, border, text
 "pres": ("#1F2A44", "#1F2A44", "#FFFFFF"),
 "staff":("#EDE7F6", "#7E57C2", "#311B92"),
 "exec": ("#1565C0", "#0D47A1", "#FFFFFF"),
 "gm":   ("#E0F2F1", "#00897B", "#004D40"),
 "ldr":  ("#FFF3E0", "#FB8C00", "#5D3A00"),
 "mem":  ("#F1F8E9", "#7CB342", "#33691E"),
}
LINE = "#90A4AE"

def L(name, dept, kind): return dict(name=name, dept=dept, kind=kind, kids=[])
def G(name, dept, kids): d = L(name, dept, "gm"); d["kids"] = kids; return d

execs = [
 ("COO", "最高執行責任者", [
    G("GM", "アプリ事業部", []),
    G("GM", "制作事業部", [L("進行管理 (Ldr)", "制作事業部", "ldr"), L("デザイン (Ldr)", "制作事業部", "ldr")]),
    G("GM", "メディア事業部", [L("編集 (Ldr)", "メディア事業部", "ldr"), L("執筆 (Member)", "メディア事業部", "mem"), L("ビジュアル制作 (Member)", "メディア事業部", "mem")]),
 ]),
 ("CRO", "最高収益責任者", [L("提案担当 (Ldr)", "制作事業部", "ldr")]),
 ("CFO", "最高財務責任者", [L("見積審査 (Ldr)", "制作事業部", "ldr"), L("法務・リスク (Ldr)", "全社", "ldr"), L("経理 (Member)", "全社", "mem")]),
 ("CSO", "最高戦略責任者", [L("根拠確認 (Ldr)", "全社", "ldr"), L("市場調査 (Ldr)", "全社", "ldr"), L("新規事業 (Ldr)", "全社", "ldr")]),
 ("CTO", "最高技術責任者", [L("検査 (Ldr)", "全社", "ldr"), L("運用監視 (Ldr)", "アプリ事業部", "ldr"), L("制作技術 (Ldr)", "制作事業部", "ldr"), L("セキュリティ (Ldr)", "全社", "ldr")]),
 ("CCO", "最高顧客責任者", [L("ユーザー対応 (Ldr)", "アプリ事業部", "ldr"), L("納品後対応 (Ldr)", "制作事業部", "ldr")]),
 ("CPO", "最高プロダクト責任者", [L("UIデザイナー (Ldr)", "アプリ事業部", "ldr")]),
 ("CMO", "最高マーケティング責任者", [L("表現審査 (Ldr)", "全社", "ldr"), L("獲得文章 (Member)", "アプリ事業部", "mem"), L("獲得文章 (Member)", "制作事業部", "mem")]),
]

W, H = 2400, 1265
img = Image.new("RGB", (W*S, H*S), "#FAFBFC")
d = ImageDraw.Draw(img)
fT = jp(BLD, 40); fSub = jp(REG, 20)
fName = jp(BLD, 22); fDept = jp(REG, 17)
fExec = jp(BLD, 30); fExecS = jp(REG, 15)
fPres = jp(BLD, 34); fLeg = jp(REG, 18)

def s(v): return int(v*S)
def line(pts, w=2.5): d.line([(s(x), s(y)) for x, y in pts], fill=LINE, width=s(w), joint="curve")
def box(x, y, w, h, kind, t1, t2=None, f1=fName, f2=fDept, r=12):
    fill, bd, tc = COL[kind]
    # shadow
    d.rounded_rectangle([s(x+3), s(y+4), s(x+w+3), s(y+h+4)], radius=s(r), fill="#E3E7EB")
    d.rounded_rectangle([s(x), s(y), s(x+w), s(y+h)], radius=s(r), fill=fill, outline=bd, width=s(2))
    cx = s(x + w/2)
    if t2:
        d.text((cx, s(y + h*0.40)), t1, font=f1, fill=tc, anchor="mm")
        sub = tc if kind in ("pres", "exec") else bd
        d.text((cx, s(y + h*0.74)), t2, font=f2, fill=sub if kind not in ("pres","exec") else "#DCE6F5", anchor="mm")
    else:
        d.text((cx, s(y + h/2)), t1, font=f1, fill=tc, anchor="mm")

# title
d.text((s(60), s(40)), "Bot組織体制", font=fT, fill="#1F2A44")
d.text((s(62), s(100)), "2026/9/27 時点 ・ 3事業部（アプリ／制作／メディア）", font=fSub, fill="#607D8B")

# president
pw, ph = 240, 80
px, py = W/2 - pw/2, 60
box(px, py, pw, ph, "pres", "社長", f1=fPres, r=16)
# staff (社長直下) to the right
sw, sh = 170, 56
sy = py + ph + 30
bus_x = W/2
staff_x0 = W/2 + 90
d.text((s(staff_x0), s(sy - 22)), "社長直下", font=fDept, fill="#7E57C2", anchor="lm")
line([(bus_x, py+ph), (bus_x, 290)])
line([(bus_x, sy + sh/2), (staff_x0 + 2*sw + 30, sy + sh/2)])
for i, n in enumerate(["社長補佐", "秘書"]):
    bx = staff_x0 + i*(sw + 30)
    box(bx, sy, sw, sh, "staff", n, r=12)

# exec columns
margin = 50
colw = [440] + [262]*7
total = sum(colw); gap = (W - 2*margin - total) / 7
ey, eh = 330, 84
bar_y = 290
xs = []; x = margin
for w in colw: xs.append(x); x += w + gap
ecx = [xs[i] + colw[i]/2 for i in range(8)]
line([(ecx[0], bar_y), (ecx[-1], bar_y)])
BH, VG = 66, 18
for i, (code, title, kids) in enumerate(execs):
    ew = 200
    ex = ecx[i] - ew/2
    line([(ecx[i], bar_y), (ecx[i], ey)])
    box(ex, ey, ew, eh, "exec", code, title, f1=fExec, f2=fExecS, r=14)
    # children stacked vertically, trunk on left
    trunk = xs[i] + 18
    cy = ey + eh + 30
    line([(ecx[i], ey+eh), (ecx[i], ey+eh+14), (trunk, ey+eh+14)])
    last_mid = None
    cx0 = trunk + 22
    for k in kids:
        bw = xs[i] + colw[i] - cx0
        if k["kind"] == "gm":
            bw = 220
        box(cx0, cy, bw, BH, k["kind"], k["name"] if k["kind"] != "gm" else "GM", k["dept"])
        mid = cy + BH/2
        line([(trunk, mid), (cx0, mid)]); last_mid = mid
        gy = cy + BH
        cy += BH + VG
        if k["kind"] == "gm":
            if not k["kids"]:
                d.text((s(cx0 + 12), s(cy + 2)), "部下なし（全社側を利用）", font=fDept, fill="#90A4AE", anchor="lm")
                cy += 22 + VG
            t2 = cx0 + 30; c2 = t2 + 22
            lm2 = None
            for g in k["kids"]:
                bw2 = xs[i] + colw[i] - c2
                box(c2, cy, bw2, BH, g["kind"], g["name"], g["dept"])
                m2 = cy + BH/2
                line([(t2, m2), (c2, m2)]); lm2 = m2
                cy += BH + VG
            if lm2: line([(t2, gy), (t2, lm2)])
    if last_mid: line([(trunk, ey+eh+14), (trunk, last_mid)])
    if code == "COO": coo_bottom = cy
    max_bottom = max(globals().get("max_bottom", 0), cy)

# legend
ly = max(coo_bottom, max_bottom) + 33
items = [("pres","社長"),("staff","社長直下"),("exec","役員"),("gm","GM"),("ldr","リーダー (Ldr)"),("mem","メンバー (Member)")]
lx = 60
d.text((s(lx), s(ly+14)), "凡例", font=fName, fill="#37474F", anchor="lm"); lx += 70
for kind, lab in items:
    fill, bd, _ = COL[kind]
    d.rounded_rectangle([s(lx), s(ly), s(lx+40), s(ly+28)], radius=s(7), fill=fill, outline=bd, width=s(2))
    d.text((s(lx+52), s(ly+14)), lab, font=fLeg, fill="#37474F", anchor="lm")
    lx += 52 + d.textlength(lab, font=fLeg)/S + 40
d.text((s(W-60), s(ly+14)), "（部署名は各ボックス下段：所属事業部／全社）", font=fDept, fill="#90A4AE", anchor="rm")
print("coo bottom", coo_bottom, "legend y", ly, "H", H)
img = img.resize((W, H), Image.LANCZOS)
img.save("/workspace/orgchart/orgchart.png", optimize=True)
