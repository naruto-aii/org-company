import re, math, cairosvg
from PIL import Image
src=open('mark.svg').read()
ring=re.search(r'id="ring-leaves"[^>]*?d="([^"]+)"',src).group(1)
dot=re.search(r'id="dot"[^>]*?d="([^"]+)"',src).group(1)
G7,G5,G9,O5,C1,C0='#2D7448','#5AA277','#14522F','#F6892B','#FEF9EE','#FFFFFF'
def mark(ringc,dotc,w=700):
    s=w/66; x=(1024-66*s)/2; y=(1024-68*s)/2
    return f'<g transform="translate({x:.1f},{y:.1f}) scale({s:.4f})"><path d="{ring}" fill="{ringc}" fill-rule="evenodd"/><path d="{dot}" fill="{dotc}" fill-rule="evenodd"/></g>'
def svg(bg,body): return f'<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024"><rect width="1024" height="1024" fill="{bg}"/>{body}</svg>'
def arc(cx,cy,r,a0,a1,col,sw):
    p=lambda a:(cx+r*math.cos(math.radians(a-90)),cy+r*math.sin(math.radians(a-90)))
    (x0,y0),(x1,y1)=p(a0),p(a1); large=1 if a1-a0>180 else 0
    return f'<path d="M{x0:.1f},{y0:.1f} A{r},{r} 0 {large} 1 {x1:.1f},{y1:.1f}" stroke="{col}" stroke-width="{sw}" stroke-linecap="round" fill="none"/>'
A=svg(C1,mark(G7,O5))
B=svg(G7,mark(C0,O5))
# C: 3色の輪（たんぱく質・炭水化物・脂質の色）＋中央の点
gap=26
C=svg(C1, arc(512,512,290,20+gap/2,160-gap/2,G7,150)+arc(512,512,290,160+gap/2,290-gap/2,O5,150)+arc(512,512,290,290+gap/2,380-gap/2,G5,150))
for n,s in [('A',A),('B',B),('C',C)]:
    fn=f'karonavi_icon_{n}.png'
    cairosvg.svg2png(bytestring=s.encode(),write_to=fn,output_width=1024,output_height=1024)
    im=Image.open(fn).convert('RGB'); im.save(fn)
    print(fn,Image.open(fn).mode,Image.open(fn).size)
# 確認用: 実寸比較シート（角丸マスク、1024/180/60/40）
sheet=Image.new('RGB',(3*420,460),'#DDDDDD')
from PIL import ImageDraw
for i,n in enumerate('ABC'):
    im=Image.open(f'karonavi_icon_{n}.png')
    x=i*420+20; y=20
    for sz in (240,120,60,40):
        t=im.resize((sz,sz),Image.LANCZOS); m=Image.new('L',(sz,sz),0)
        ImageDraw.Draw(m).rounded_rectangle([0,0,sz-1,sz-1],radius=int(sz*0.225),fill=255)
        sheet.paste(t,(x,y),m); x+=sz+10 if sz<240 else 0
        if sz==240: x=i*420+20; y=280
sheet.save('preview_sheet.png')
