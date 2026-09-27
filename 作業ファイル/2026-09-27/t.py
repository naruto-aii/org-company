hw_from='ｦｧｨｩｪｫｬｭｮｯｰｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜﾝ'
hw_to='をぁぃぅぇぉゃゅょっーあいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほまみむめもやゆよらりるれろわん'
def isw(c):
  cp=ord(c); return 48<=cp<=57 or 97<=cp<=122 or 12353<=cp<=12438 or 12449<=cp<=12538 or 19968<=cp<=40959 or cp==12540
def norm(v):
  out=''
  for ch in v:
    cp=ord(ch)
    if cp in (12288,32,9,10,13):
      if out and out[-1]!=' ': out+=' '
      continue
    if 65296<=cp<=65305: cp=48+cp-65296
    elif 65313<=cp<=65338: cp=97+cp-65313
    elif 65345<=cp<=65370: cp=97+cp-65345
    else:
      i=hw_from.find(ch)
      if i>=0: ch=hw_to[i]; cp=ord(ch)
    if 12449<=cp<=12531: cp-=96
    if 65<=cp<=90: cp=97+cp-65
    c=chr(cp)
    if isw(c): out+=c
    elif out and out[-1]!=' ': out+=' '
  return out.strip()
def contains(n,t):
  f=0
  while True:
    a=n.find(t,f)
    if a<0: return False
    b=n[a-1] if a>0 else None; af=n[a+len(t)] if a+len(t)<len(n) else None
    if (b is None or not isw(b)) and (af is None or not isw(af)): return True
    f=a+1
words=['fuck','shit','ちんぽ','きちがい','セックス','死ね','エロ','くそ']
def banned(n):
  s=norm(n); c=s.replace(' ','')
  if not s: return False
  for w in words:
    t=norm(w).replace(' ','')
    sub = not any(ch.isascii() and ch.isalnum() for ch in t) and len(t)>=2 and t!='えろ'
    if sub:
      if t in c: return True
    elif contains(s,t) or contains(c,t): return True
  return False
tests=['FUCK','ｆｕｃｋ','f u c k','f\u200bck','f\u200buck','fück','f*ck','sh1t','ｼｯﾄ','\u0441hit','𝐟𝐮𝐜𝐤','ﾁﾝﾎﾟ','ちんほ\u309a','ｷﾁｶﾞｲ','ｾｯｸｽ','セッ クス','氏ね','エロい','クソ','ｸｿ','ｴﾛ']
for x in tests: print(repr(x), banned(x))
import unicodedata
print('NFKC fixes:',[ (x,banned(unicodedata.normalize('NFKC',x))) for x in ['ﾁﾝﾎﾟ','ちんほ\u309a','ｷﾁｶﾞｲ','𝐟𝐮𝐜𝐤']])
