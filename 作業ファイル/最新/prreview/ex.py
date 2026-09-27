import json,sys,re
for p in sys.argv[1:]:
  t=open(p).read(); d,_=json.JSONDecoder().raw_decode(t)
  sha=d['sha'][:7]
  out=open(f"prreview/c_{sha}.patch","w")
  for f in d['files']:
    out.write(f"### FILE {f['filename']} ({f['status']})\n{f.get('patch','<no patch>')}\n")
  print(sha, len(d['files']), [f['filename'] for f in d['files']])
