import json,sys
t=open(sys.argv[1]).read()
d,end=json.JSONDecoder().raw_decode(t)
for c in d:
  print(c['sha'][:12], c['commit']['committer']['date'], [p['sha'][:7] for p in c['parents']], c['commit']['message'].splitlines()[0][:90])
