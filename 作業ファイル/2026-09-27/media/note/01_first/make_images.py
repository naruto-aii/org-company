# 連載ビジュアル生成スクリプト（Pillowによる手続き的描画、文字なし）
from PIL import Image, ImageDraw
import math
NAVY="#1F2A44"; OFF="#F7F5F0"; CORAL="#FF7A45"; TEAL="#3BB3A8"; GRAY="#D9DDE3"; MID="#8A93A6"; NAVY2="#2A3656"; PURPLE="#8E7CF0"  # TEAL=作る担当, PURPLE=確かめる担当
S=3  # 超解像描画倍率（アンチエイリアス用）

def robot(d,cx,cy,r,body,face=OFF,eye=NAVY):
    # 丸みのある小さなロボット：角丸の頭＋アンテナ＋点の目
    w=r*2; h=r*1.7
    d.line([(cx,cy-h/2),(cx,cy-h/2-r*0.55)],fill=body,width=max(2,int(r*0.12)))
    d.ellipse([cx-r*0.17,cy-h/2-r*0.75,cx+r*0.17,cy-h/2-r*0.41],fill=CORAL if body!=CORAL else TEAL)
    d.rounded_rectangle([cx-w/2,cy-h/2,cx+w/2,cy+h/2],radius=r*0.55,fill=body)
    d.rounded_rectangle([cx-w*0.36,cy-h*0.28,cx+w*0.36,cy+h*0.24],radius=r*0.35,fill=face)
    for dx in(-0.32,0.32):
        d.ellipse([cx+dx*r-r*0.12,cy-r*0.14,cx+dx*r+r*0.12,cy+r*0.1],fill=eye)
    d.ellipse([cx-r*1.12,cy-r*0.2,cx-r*0.92,cy+r*0.2],fill=body)
    d.ellipse([cx+r*0.92,cy-r*0.2,cx+r*1.12,cy+r*0.2],fill=body)

def person(d,cx,cy,r,col):
    # 顔を描かない抽象シルエット（円＋角丸の胴）
    d.ellipse([cx-r*0.55,cy-r*1.35,cx+r*0.55,cy-r*0.25],fill=col)
    d.rounded_rectangle([cx-r,cy-r*0.05,cx+r,cy+r*1.3],radius=r*0.7,fill=col)

def dots(d,W,H,step,col,rad):
    for x in range(step//2,W,step):
        for y in range(step//2,H,step):
            d.ellipse([x-rad,y-rad,x+rad,y+rad],fill=col)

def save(img,path,size):
    img.resize(size,Image.LANCZOS).save(path,optimize=True)

def division(d,cx,cy,r,col,win):
    # 事業部：角丸ブロック＋窓（抽象的な建物）
    d.rounded_rectangle([cx-r,cy-r,cx+r,cy+r],radius=r*0.3,fill=col)
    for i in(-1,1):
        for j in(-1,1):
            x=cx+i*r*0.38; y=cy+j*r*0.38
            d.rounded_rectangle([x-r*0.2,y-r*0.2,x+r*0.2,y+r*0.2],radius=r*0.06,fill=win)

def magnifier(d,cx,cy,r,col,bg):
    # 虫めがね：作る担当と確かめる担当をつなぐ
    d.ellipse([cx-r*1.35,cy-r*1.35,cx+r*1.35,cy+r*1.35],fill=bg)
    lw=max(3,int(r*0.28))
    d.ellipse([cx-r*0.75,cy-r*0.85,cx+r*0.55,cy+r*0.45],outline=col,width=lw)
    d.line([(cx+r*0.35,cy+r*0.25),(cx+r*0.9,cy+r*0.85)],fill=col,width=int(lw*1.3))

def org_tree(d,x0,x1,ys,c):
    # ys: 社長・役員・事業部・担当 の各段のy。c: 配色dict
    k=lambda v:v*S
    cx=(x0+x1)/2; W=x1-x0
    ceo=(cx,ys[0]); offs=[(x0+W*(i+0.5)/4,ys[1]) for i in range(4)]
    divs=[(x0+W*(i+0.5)/3,ys[2]) for i in range(3)]
    lw=k(4); L=c["line"]
    def elbow(p,q):
        my=(p[1]+q[1])/2
        d.line([(k(p[0]),k(p[1])),(k(p[0]),k(my)),(k(q[0]),k(my)),(k(q[0]),k(q[1]))],fill=L,width=lw,joint="curve")
    for o in offs: elbow(ceo,o)
    for dv in divs: elbow(offs[0],dv)
    staff=[]
    for dv in divs:
        m=(dv[0]-W/10,ys[3]); ch=(dv[0]+W/10,ys[3]); staff.append((m,ch))
        elbow(dv,m); elbow(dv,ch)
    # 作る担当→確かめる担当の連結線（段の下側）
    for m,ch in staff:
        d.line([(k(m[0]),k(m[1])),(k(ch[0]),k(ch[1]))],fill=c["link"],width=k(4))
    # ノード描画
    d.ellipse([k(cx-c["cr"]),k(ys[0]-c["cr"]),k(cx+c["cr"]),k(ys[0]+c["cr"])],fill=c["ceo_bg"])
    person(d,k(cx),k(ys[0]+c["cr"]*0.1),k(c["cr"]*0.5),c["ceo_fg"])
    for o in offs:
        d.ellipse([k(o[0]-c["or"]*1.75),k(o[1]-c["or"]*1.75),k(o[0]+c["or"]*1.75),k(o[1]+c["or"]*1.75)],fill=c["plate"],outline=c["ring"],width=k(2))
        robot(d,k(o[0]),k(o[1]+c["or"]*0.2),k(c["or"]),c["officer"])
    for dv in divs: division(d,k(dv[0]),k(dv[1]),k(c["dr"]),c["div"],c["div_win"])
    for m,ch in staff:
        for p,col in((m,TEAL),(ch,PURPLE)):
            d.ellipse([k(p[0]-c["sr"]*1.75),k(p[1]-c["sr"]*1.75),k(p[0]+c["sr"]*1.75),k(p[1]+c["sr"]*1.75)],fill=c["plate"],outline=col,width=k(3))
            robot(d,k(p[0]),k(p[1]+c["sr"]*0.2),k(c["sr"]),col)
        mx=(m[0]+ch[0])/2; my=m[1]
        magnifier(d,k(mx),k(my),k(c["mr"]),c["mag"],c["mag_bg"])

def header_A():
    # 案A：明るい地、組織図を右側に配置、左〜中央に文字用の余白
    W,H=1280*S,670*S; im=Image.new("RGB",(W,H),OFF); d=ImageDraw.Draw(im)
    dots(d,W,H,40*S,"#ECE9E2",2*S)
    org_tree(d,660,1240,[88,228,390,540],dict(line=GRAY,link=GRAY,ceo_bg=CORAL,ceo_fg=OFF,cr=58,
        plate="#FFFFFF",ring=GRAY,officer=NAVY,**{"or":22},dr=30,div=NAVY2,div_win=OFF,sr=17,mr=15,mag=NAVY,mag_bg=OFF))
    for x,y,c in [(90*S,90*S,TEAL),(110*S,580*S,PURPLE),(560*S,610*S,CORAL)]:
        d.ellipse([x-10*S,y-10*S,x+10*S,y+10*S],fill=c)
    save(im,"header_A.png",(1280,670))

def header_B():
    # 案B：濃紺の地、組織図を左側に大きめに配置、右〜中央に文字用の余白
    W,H=1280*S,670*S; im=Image.new("RGB",(W,H),NAVY); d=ImageDraw.Draw(im)
    dots(d,W,H,48*S,NAVY2,2*S)
    d.ellipse([-260*S,380*S,760*S,1400*S],fill=NAVY2)
    org_tree(d,30,640,[92,236,400,556],dict(line="#46557D",link="#5A6A94",ceo_bg=CORAL,ceo_fg=NAVY,cr=62,
        plate=NAVY,ring="#46557D",officer=MID,**{"or":23},dr=31,div=GRAY,div_win=NAVY2,sr=18,mr=16,mag=OFF,mag_bg=NAVY2))
    import random; random.seed(7)
    for _ in range(22):
        x=random.randint(700,1250)*S; y=random.randint(30,640)*S
        if 700*S<x<1200*S and 150*S<y<520*S: continue
        r=random.choice([3,4,5])*S; d.ellipse([x-r,y-r,x+r,y+r],fill=random.choice([MID,TEAL,PURPLE]))
    save(im,"header_B.png",(1280,670))


def icon_A():
    W=1024*S; im=Image.new("RGB",(W,W),NAVY); d=ImageDraw.Draw(im); c=W//2
    d.ellipse([c-400*S,c-400*S,c+400*S,c+400*S],outline=NAVY2,width=6*S)
    for a,col in [(-60,TEAL),(60,TEAL),(180,CORAL)]:
        x=c+330*S*math.cos(math.radians(a)); y=c+330*S*math.sin(math.radians(a))
        d.ellipse([x-30*S,y-30*S,x+30*S,y+30*S],fill=col)
    robot(d,c,c+40*S,170*S,CORAL)
    save(im,"icon_A.png",(1024,1024))

def icon_B():
    W=1024*S; im=Image.new("RGB",(W,W),OFF); d=ImageDraw.Draw(im); c=W//2
    top=(c,330*S); kids=[(290*S,690*S,TEAL),(c,720*S,CORAL),(734*S,690*S,TEAL)]
    for x,y,col in kids: d.line([top,(x,y)],fill=GRAY,width=10*S)
    d.ellipse([top[0]-130*S,top[1]-130*S,top[0]+130*S,top[1]+130*S],fill=NAVY)
    person(d,top[0],top[1]+10*S,68*S,OFF)
    for x,y,col in kids:
        d.ellipse([x-95*S,y-95*S,x+95*S,y+95*S],fill="#FFFFFF",outline=GRAY,width=5*S)
        robot(d,x,y+10*S,50*S,col)
    save(im,"icon_B.png",(1024,1024))

def place_center(layer,scale,W,H):
    # 透明レイヤーに描いた図を外接矩形で切り出し、scale倍して画像の中央に置く
    box=layer.getbbox(); fig=layer.crop(box)
    fig=fig.resize((int(fig.width*scale),int(fig.height*scale)),Image.LANCZOS)
    return fig,((W-fig.width)//2,(H-fig.height)//2)

def header_A2():
    # 案A改2：案Aの組織図を0.8倍に縮め、画像の上下左右中央に置く（一覧で上下左右が切り取られても欠けない）
    W,H=1280*S,670*S; im=Image.new("RGB",(W,H),OFF); d=ImageDraw.Draw(im)
    dots(d,W,H,40*S,"#ECE9E2",2*S)
    lay=Image.new("RGBA",(W,H),(0,0,0,0)); ld=ImageDraw.Draw(lay)
    org_tree(ld,350,930,[88,228,390,540],dict(line=GRAY,link=GRAY,ceo_bg=CORAL,ceo_fg=OFF,cr=58,
        plate="#FFFFFF",ring=GRAY,officer=NAVY,**{"or":22},dr=30,div=NAVY2,div_win=OFF,sr=17,mr=15,mag=NAVY,mag_bg=OFF))
    fig,pos=place_center(lay,0.8,W,H); im.paste(fig,pos,fig)
    for x,y,c in [(90*S,90*S,TEAL),(110*S,580*S,PURPLE),(1180*S,600*S,CORAL)]:
        d.ellipse([x-10*S,y-10*S,x+10*S,y+10*S],fill=c)
    save(im,"header_A2.png",(1280,670))

import sys
for f in ((header_A2,) if 'A2' in sys.argv else (header_A,header_B,icon_A,icon_B,header_A2)): f()
