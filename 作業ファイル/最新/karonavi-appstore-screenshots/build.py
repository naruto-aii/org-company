import cairosvg
from PIL import Image
W,H=1320,2868
G9,G7,N7,O5,C1,G2='#14522F','#2D7448','#55635B','#F6892B','#FEF9EE','#C9E4D3'
shots=[
 ('01_home',['今日のkcalと','栄養バランスがひと目で'],'たんぱく質・炭水化物・脂質の目安も表示'),
 ('02_barcode',['バーコードを読んで','食事をすばやく記録'],'パッケージの食品はカメラで読み取り'),
 ('03_public_food',['みんなが登録した食品から','すぐに探せる'],'公開食品を名前で検索'),
 ('04_history',['食べたものを','日ごとにふり返る'],'記録した食事を日付ごとに確認'),
 ('05_plus',['検索もテンプレートも','カロナビ+なら無制限'],'記録などの基本の機能は無料で使えます'),
]
pw=960; ph=round(pw*H/W); px=(W-pw)//2; py=H-ph-90
for name,head,sub in shots:
    t=''.join(f'<text x="660" y="{230+i*120}" font-family="Zen Maru Gothic" font-weight="bold" font-size="96" fill="{G9}" text-anchor="middle">{l}</text>' for i,l in enumerate(head))
    svg=f'''<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">
<rect width="{W}" height="{H}" fill="{C1}"/>
<circle cx="660" cy="100" r="16" fill="{O5}"/>
{t}
<text x="660" y="{230+len(head)*120+20}" font-family="Zen Maru Gothic" font-weight="500" font-size="50" fill="{N7}" text-anchor="middle">{sub}</text>
<g id="screenshot-slot">
<rect x="{px}" y="{py}" width="{pw}" height="{ph}" rx="96" fill="#FFFFFF" stroke="{G2}" stroke-width="6" stroke-dasharray="28 20"/>
<text x="660" y="{py+ph//2-30}" font-family="Zen Maru Gothic" font-weight="500" font-size="44" fill="#7C8880" text-anchor="middle">スクリーンショット差し込み枠</text>
<text x="660" y="{py+ph//2+40}" font-family="Zen Maru Gothic" font-weight="500" font-size="36" fill="#7C8880" text-anchor="middle">x={px} y={py} 幅{pw} 高さ{ph}（1320×2868を縮小）</text>
</g></svg>'''
    open(name+'.svg','w').write(svg)
    cairosvg.svg2png(bytestring=svg.encode(),write_to=name+'.png')
    Image.open(name+'.png').convert('RGB').save(name+'.png')
ims=[Image.open(s[0]+'.png').resize((330,717)) for s in shots]
sh=Image.new('RGB',(5*350+10,737),'#DDDDDD')
for i,im in enumerate(ims): sh.paste(im,(10+i*350,10))
sh.save('overview.png'); print(px,py,pw,ph)
