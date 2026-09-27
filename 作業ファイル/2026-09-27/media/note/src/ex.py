import sys,re,html
from html.parser import HTMLParser
s=open(sys.argv[1],encoding='utf-8').read()
m=re.search(r'<div class="article-body"[^>]*>(.*?)</div>\s*(<div class="article-attachments|<footer|<div class="article-footer)',s,re.S)
b=m.group(1) if m else s
b=re.sub(r'<(br|/p|/li|/h\d|/tr|/div)[^>]*>','\n',b)
b=re.sub(r'<t[dh][^>]*>',' | ',b)
b=re.sub(r'<[^>]+>','',b)
t=html.unescape(b)
t=re.sub(r'\n\s*\n+','\n',t)
print(t)
m=re.search(r'datetime="([^"]+)"',s); print("DATETIME",re.findall(r'datetime="([^"]+)"',s)[:3])
