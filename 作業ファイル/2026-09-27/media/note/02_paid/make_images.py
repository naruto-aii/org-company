# 有料回（02_paid）見出し画像：Pillowによる手続き的描画、文字なし
# 部品（robot/person/dots/magnifier）と配色は 01_first/make_images.py から流用
from PIL import Image, ImageDraw
import os
NAVY="#1F2A44"; OFF="#F7F5F0"; CORAL="#FF7A45"; TEAL="#3BB3A8"; GRAY="#D9DDE3"; MID="#8A93A6"; NAVY2="#2A3656"; PURPLE="#8E7CF0"
S=3; OUT=os.path.dirname(os.path.abspath(__file__))
k=lambda v:v*S

def robot(d,cx,cy,r,body,face=OFF,eye=NAVY):
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
    d.ellipse([cx-r*0.55,cy-r*1.35,cx+r*0.55,cy-r*0.25],fill=col)
    d.rounded_rectangle([cx-r,cy-r*0.05,cx+r,cy+r*1.3],radius=r*0.7,fill=col)

def dots(d,W,H,step,col,rad):
    for x in range(step//2,W,step):
        for y in range(step//2,H,step):
            d.ellipse([x-rad,y-rad,x+rad,y+rad],fill=col)

def magnifier(d,cx,cy,r,col,bg):
    d.ellipse([cx-r*1.35,cy-r*1.35,cx+r*1.35,cy+r*1.35],fill=bg)
    lw=max(3,int(r*0.28))
    d.ellipse([cx-r*0.75,cy-r*0.85,cx+r*0.55,cy+r*0.45],outline=col,width=lw)
    d.line([(cx+r*0.35,cy+r*0.25),(cx+r*0.9,cy+r*0.85)],fill=col,width=int(lw*1.3))

def ceo(d,cx,cy,r,fg):
    d.ellipse([k(cx-r),k(cy-r),k(cx+r),k(cy+r)],fill=CORAL)
    person(d,k(cx),k(cy+r*0.1),k(r*0.5),fg)

def card(d,x0,y0,x1,y1,role,fill,linec,tail=None,check=False):
    # 指示書カード：役割色の帯＋灰色の横線（文字なし）。tail=('r'|'d', 先端座標) で吹き出しの尾
    if tail:
        s,(tx,ty)=tail
        if s=='r': pts=[(x1-2,(y0+y1)/2-14),(tx,ty),(x1-2,(y0+y1)/2+14)]
        else: pts=[((x0+x1)/2-16,y1-2),(tx,ty),((x0+x1)/2+16,y1-2)]
        d.polygon([(k(a),k(b)) for a,b in pts],fill=fill)
    d.rounded_rectangle([k(x0),k(y0),k(x1),k(y1)],radius=k(16),fill=fill)
    d.rounded_rectangle([k(x0),k(y0),k(x0+14),k(y1)],radius=k(7),fill=role)  # 左端の役割色の帯
    n=3 if (y1-y0)<130 else 4; gap=(y1-y0-36)/(n-1) if n>1 else 0
    lens=[1.0,0.82,0.92,0.6]
    for i in range(n):
        y=y0+18+gap*i; lx=x0+36
        if check:
            d.rounded_rectangle([k(lx),k(y-8),k(lx+16),k(y+8)],radius=k(4),outline=role,width=k(3)); lx+=30
        L=(x1-24-lx)*lens[i]
        d.rounded_rectangle([k(lx),k(y-4),k(lx+L),k(y+4)],radius=k(4),fill=linec)

def plate(d,cx,cy,r,fill,ring):
    d.ellipse([k(cx-r*1.75),k(cy-r*1.75),k(cx+r*1.75),k(cy+r*1.75)],fill=fill,outline=ring,width=k(3))

def header_A():
    # 案A：生成りの地。右寄りに縦3段「指示書カード→役割ロボット」、社長はその左。左側は文字用の余白
    W,H=1280*S,670*S; im=Image.new("RGB",(W,H),OFF); d=ImageDraw.Draw(im)
    dots(d,W,H,40*S,"#ECE9E2",2*S)
    rows=[(135,NAVY,False),(335,TEAL,False),(535,PURPLE,True)]
    cx,cy=640,335; rx=1150
    # 社長→各カードへの直角折れ線
    for y,_,_ in rows:
        d.line([(k(cx),k(cy)),(k(700),k(cy)),(k(700),k(y)),(k(740),k(y))],fill=GRAY,width=k(5),joint="curve")
    # 作る→確かめるの連結（縦）と虫めがね
    d.line([(k(rx),k(335)),(k(rx),k(535))],fill=GRAY,width=k(5))
    for y,col,chk in rows:
        card(d,740,y-62,1030,y+62,col,"#FFFFFF",GRAY,tail=('r',(1078,y)),check=chk)
        plate(d,rx,y,22,"#FFFFFF",col if col!=NAVY else GRAY)
        robot(d,k(rx),k(y+4),k(22),col)
    magnifier(d,k(rx),k(435),k(15),NAVY,OFF)
    ceo(d,cx,cy,52,OFF)
    for x,y,c in [(95,95,TEAL),(120,585,PURPLE),(540,600,GRAY)]:
        d.ellipse([k(x-9),k(y-9),k(x+9),k(y+9)],fill=c)
    im.resize((1280,670),Image.LANCZOS).save(os.path.join(OUT,"header_A.png"),optimize=True)

def place_center(layer,scale,W,H):
    # 透明レイヤーに描いた図を外接矩形で切り出し、scale倍して画像の中央に置く
    box=layer.getbbox(); fig=layer.crop(box)
    fig=fig.resize((int(fig.width*scale),int(fig.height*scale)),Image.LANCZOS)
    return fig,((W-fig.width)//2,(H-fig.height)//2)

def header_A2():
    # 採用A案の中央寄せ版：図（社長・指示書カード・ロボット）を0.82倍に縮め、上下左右の中央に置く
    W,H=1280*S,670*S; im=Image.new("RGB",(W,H),OFF); d=ImageDraw.Draw(im)
    dots(d,W,H,40*S,"#ECE9E2",2*S)
    lay=Image.new("RGBA",(W,H),(0,0,0,0)); ld=ImageDraw.Draw(lay)
    rows=[(135,NAVY,False),(335,TEAL,False),(535,PURPLE,True)]
    cx,cy=640,335; rx=1150
    for y,_,_ in rows:
        ld.line([(k(cx),k(cy)),(k(700),k(cy)),(k(700),k(y)),(k(740),k(y))],fill=GRAY,width=k(5),joint="curve")
    ld.line([(k(rx),k(335)),(k(rx),k(535))],fill=GRAY,width=k(5))
    for y,col,chk in rows:
        card(ld,740,y-62,1030,y+62,col,"#FFFFFF",GRAY,tail=('r',(1078,y)),check=chk)
        plate(ld,rx,y,22,"#FFFFFF",col if col!=NAVY else GRAY)
        robot(ld,k(rx),k(y+4),k(22),col)
    magnifier(ld,k(rx),k(435),k(15),NAVY,OFF)
    ceo(ld,cx,cy,52,OFF)
    fig,pos=place_center(lay,0.82,W,H); im.paste(fig,pos,fig)
    for x,y,c in [(95,95,TEAL),(120,585,PURPLE),(1185,590,GRAY)]:
        d.ellipse([k(x-9),k(y-9),k(x+9),k(y+9)],fill=c)
    im.resize((1280,670),Image.LANCZOS).save(os.path.join(OUT,"header_A2.png"),optimize=True)

def header_B():
    # 案B：紺の地。左の面の中に横並び3体、それぞれの頭上に吹き出し型の指示書。右側は文字用の余白
    W,H=1280*S,670*S; im=Image.new("RGB",(W,H),NAVY); d=ImageDraw.Draw(im)
    dots(d,W,H,48*S,NAVY2,2*S)
    d.rounded_rectangle([k(40),k(40),k(720),k(630)],radius=k(36),fill=NAVY2)
    cols=[(160,MID,False),(380,TEAL,False),(600,PURPLE,True)]
    cx,cy=120,110
    # 社長→各吹き出しへ（上辺を走る直角折れ線）
    d.line([(k(cx),k(cy)),(k(600),k(cy))],fill="#46557D",width=k(5))
    for x,_,_ in cols:
        d.line([(k(x),k(cy)),(k(x),k(190))],fill="#46557D",width=k(5))
    d.line([(k(380),k(530)),(k(600),k(530))],fill="#5A6A94",width=k(5))
    for x,col,chk in cols:
        card(d,x-95,190,x+95,390,col,OFF,GRAY,tail=('d',(x,440)),check=chk)
        plate(d,x,530,30,NAVY2,col if col!=MID else "#46557D")
        robot(d,k(x),k(535),k(30),col)
    magnifier(d,k(490),k(530),k(18),OFF,NAVY2)
    ceo(d,cx,cy,44,NAVY)
    import random; random.seed(11)
    for _ in range(26):
        x=random.randint(760,1250); y=random.randint(30,640)
        if 800<x<1200 and 150<y<520: continue
        r=random.choice([3,4,5]); d.ellipse([k(x-r),k(y-r),k(x+r),k(y+r)],fill=random.choice([MID,TEAL,PURPLE]))
    im.resize((1280,670),Image.LANCZOS).save(os.path.join(OUT,"header_B.png"),optimize=True)

import sys
for f in ((header_A2,) if "A2" in sys.argv else (header_A,header_B,header_A2)): f()
