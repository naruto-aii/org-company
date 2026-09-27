import sys,re
fn,pat=sys.argv[1],sys.argv[2]
n=None;f=''
for l in open(fn):
    if l.startswith('diff --git'): f=l.split(' b/')[-1].strip(); n=None; continue
    m=re.match(r'^@@ -\d+(?:,\d+)? \+(\d+)',l)
    if m: n=int(m.group(1)); continue
    if n is None or l.startswith('---') or l.startswith('+++'): continue
    if l.startswith('-'): continue
    if re.search(pat,l): print(f"{f}:{n}: {l.rstrip()[1:][:120]}")
    n+=1
