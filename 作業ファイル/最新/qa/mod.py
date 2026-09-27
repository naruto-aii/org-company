W=['fuck','fucking','motherfucker','shit','bullshit','asshole','bitch','bastard','cunt','dick','cock','pussy','whore','slut','nigger','nigga','faggot','retard','rape','くそ','くそったれ','ちくしょう','ちんこ','ちんぽ','まんこ','うんこ','きんたま','ファック','セックス','フェラ','中出し','死ね','殺す','きちがい','池沼','エロ']
F='ｦｧｨｩｪｫｬｭｮｯｰｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜﾝ';T='をぁぃぅぇぉゃゅょっーあいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほまみむめもやゆよらりるれろわん'
HW={ord(a):ord(b) for a,b in zip(F,T)}
def isw(c): return 0x30<=c<=0x39 or 0x61<=c<=0x7a or 0x3041<=c<=0x3096 or 0x30a1<=c<=0x30fa or 0x4e00<=c<=0x9fff or c==0x30fc
def mp(r):
  if r in (0x3000,0x20,9,10,13): return None
  c=r
  if 0xff10<=c<=0xff19: c=0x30+c-0xff10
  elif 0xff21<=c<=0xff3a: c=0x61+c-0xff21
  elif 0xff41<=c<=0xff5a: c=0x61+c-0xff41
  else: c=HW.get(c,c)
  if 0x30a1<=c<=0x30f3: c-=0x60
  if 0x41<=c<=0x5a: c=0x61+c-0x41
  return c if isw(c) else None
def norm(s):
  o='';p=False
  for ch in s:
    m=mp(ord(ch))
    if m is None:
      if o: p=True
      continue
    if p: o+=' ';p=False
    o+=chr(m)
  return o
def bounded(h,t):
  s=0
  while True:
    i=h.find(t,s)
    if i<0: return False
    b= i==0 or not isw(ord(h[i-1])); a=i+len(t)
    af= a>=len(h) or not isw(ord(h[a]))
    if b and af: return True
    s=i+1
def banned(raw):
  sp=norm(raw)
  if not sp: return None
  cp=sp.replace(' ','')
  for w in W:
    t=norm(w).replace(' ','')
    sub = not any(c.isascii() and c.isalnum() for c in t) and t!='えろ' and len(t)>=2
    if sub:
      if t in cp: return w
    elif bounded(sp,t) or bounded(cp,t): return w
  return None
import sys
for n in sys.argv[1:]: print(n, '->', banned(n))
