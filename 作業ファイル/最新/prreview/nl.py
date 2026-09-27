import sys,re
fn,pat=sys.argv[1],sys.argv[2]
n=None
for i,l in enumerate(open(fn),1):
    m=re.match(r'^@@ -\d+(?:,\d+)? \+(\d+)',l)
    if m: n=int(m.group(1)); hunk=l.strip()[:90]; continue
    if n is None: continue
    if l.startswith('-'): continue
    if re.search(pat,l): print(f"patchline {i} newline {n} [{hunk}] {l.rstrip()[:130]}")
    n+=1
