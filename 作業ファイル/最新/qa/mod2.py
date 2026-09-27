# Port of PR26 (head 3035c58 / stacked 0efb0de) moderation: Dart path and SQL path separately
import unicodedata, re, sys
W=['fuck','fucking','motherfucker','shit','bullshit','asshole','bitch','bastard','cunt','dick','cock','pussy','whore','slut','nigger','nigga','faggot','retard','rape','くそ','くそったれ','ちくしょう','ちんこ','ちんぽ','まんこ','うんこ','きんたま','ファック','セックス','フェラ','中出し','死ね','殺す','きちがい','池沼','エロ']
BOUND=['えろ','くそ','ふぇら','まんこ']; ALLOW=['cock tail','rape seed']
HF='ｦｧｨｩｪｫｬｭｮｯｰｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜﾝ';HT='をぁぃぅぇぉゃゅょっーあいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほまみむめもやゆよらりるれろわん'
CF='àáâãäåÀÁÂÃÄÅèéêëÈÉÊËìíîïÌÍÎÏòóôõöÒÓÔÕÖùúûüÙÚÛÜýÿÝŸñÑçÇаАеЕоОрРсСуУхХіІјЈѕЅԁԀ013457@$!';CT='aaaaaaaaaaaaeeeeeeeeiiiiiiiioooooooooouuuuuuuuyyyynnccaaeeooppccyyxxiijjssddoieastasi'
DB='ｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾊﾋﾌﾍﾎ';DT='ガギグゲゴザジズゼゾダヂヅデドバビブベボ';HB='ﾊﾋﾌﾍﾎ';HTo='パピプペポ'
HW={ord(a):ord(b) for a,b in zip(HF,HT)}; CM=dict(zip(CF,CT))
def isw(c): return 0x30<=c<=0x39 or 0x61<=c<=0x7a or 0x3041<=c<=0x3096 or 0x30a1<=c<=0x30fa or 0x4e00<=c<=0x9fff or c==0x30fc
def compose(s):
  o='';i=0
  while i<len(s):
    if i+1<len(s):
      m=s[i+1]
      if m=='\uff9e' and s[i] in DB: o+=DT[DB.index(s[i])];i+=2;continue
      if m=='\uff9f' and s[i] in HB: o+=HTo[HB.index(s[i])];i+=2;continue
    o+=s[i];i+=1
  return o
def multi(s):
  for a,b in (('ß','ss'),('æ','ae'),('Æ','ae'),('œ','oe'),('Œ','oe')): s=s.replace(a,b)
  return s
def mapc(c):
  if 0xff10<=c<=0xff19: c=0x30+c-0xff10
  elif 0xff21<=c<=0xff3a: c=0x61+c-0xff21
  elif 0xff41<=c<=0xff5a: c=0x61+c-0xff41
  else: c=HW.get(c,c)
  if 0x30a1<=c<=0x30f3: c-=0x60
  if 0x41<=c<=0x5a: c=0x61+c-0x41
  return c
# ---- Dart
def d_prepare(raw):
  v=unicodedata.normalize('NFKC',compose(raw)); v=re.sub('[\u0300-\u036f]','',v)
  return ''.join(CM.get(ch,ch) for ch in multi(v))
def d_norm(s):
  o='';p=False
  for ch in s:
    if ord(ch) in (0x3000,0x20,9,10,13): m=None
    else:
      m=mapc(ord(ch)); m=m if isw(m) else None
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
    if (i==0 or not isw(ord(h[i-1]))) and (i+len(t)>=len(h) or not isw(ord(h[i+len(t)]))): return True
    s=i+1
def d_strip(sp):
  for ph in ALLOW:
    out='';read=0;frm=0
    while frm<=len(sp):
      i=sp.find(ph,frm)
      if i<0: out+=sp[read:];break
      a=i+len(ph)
      if (i==0 or not isw(ord(sp[i-1]))) and (a>=len(sp) or not isw(ord(sp[a]))):
        out+=sp[read:i]+' ';read=a;frm=a
      else: frm=i+1
    sp=out
  return re.sub(' +',' ',sp).strip()
def usesub(t): return not re.search('[a-z0-9]',t) and t not in BOUND and len(t)>=2
def d_banned(raw):
  sp=d_strip(d_norm(d_prepare(raw)))
  if not sp: return None
  cp=sp.replace(' ','')
  for w in W:
    t=d_norm(d_prepare(w)).replace(' ','')
    if not t: continue
    if usesub(t):
      if t in cp: return w
    elif bounded(sp,t) or bounded(cp,t): return w
  return None
# ---- SQL
def s_norm(p):
  v=unicodedata.normalize('NFKC',compose(p or '')); v=multi(v); v=''.join(CM.get(ch,ch) for ch in v)
  o=''
  for ch in v:
    cp=ord(ch)
    if 768<=cp<=879: continue
    if cp in (12288,32,9,10,13):
      if o and o[-1]!=' ': o+=' '
      continue
    cp=mapc(cp)
    if isw(cp): o+=chr(cp)
    elif o and o[-1]!=' ': o+=' '
  return o.strip(' ')
def s_strip(v,ph):
  frm=0
  while True:
    i=v.find(ph,frm)
    if i<0: return v
    a=i+len(ph)
    if (i==0 or not isw(ord(v[i-1]))) and (a>=len(v) or not isw(ord(v[a]))):
      v=v[:i]+' '+v[a:]; frm=i
    else: frm=i+1
def s_banned(p):
  sp=s_norm(p)
  if sp=='': return None
  for ph in ALLOW: sp=s_strip(sp,ph)
  sp=re.sub(' +',' ',sp).strip(' ')
  if sp=='': return None
  cp=sp.replace(' ','')
  for w in W:
    t=s_norm(w).replace(' ','')
    if not t: continue
    if usesub(t):
      if t in cp: return w
    elif bounded(sp,t) or bounded(cp,t): return w
  return None
if __name__=='__main__':
  for n in sys.argv[1:]:
    d,s=d_banned(n),s_banned(n); print(repr(n),'dart->',d,'sql->',s,'' if d==s else 'MISMATCH')
