"""Exact Fraction reference for binary MDF -> gap mask -> full CSV readback."""
from pathlib import Path
from fractions import Fraction
import math,struct,subprocess,sys,csv,io,json,hashlib
p=Path(__file__).resolve().parents[1];fdir=p/'analysis/precision_fixture'
exe=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else p/'_build/js/debug/build/zhaojun-coding/mdf4/cmd/export/export.js'
assert exe.is_file(),'Build cmd/export --target js or pass its compiled JS path'
capture=Path(sys.argv[2]).resolve() if len(sys.argv)>2 else None
if capture:capture.mkdir(parents=True,exist_ok=True)
scenarios=[
 ('original Previous counterexample','age_boundary',[-1.,1e16+2],[1e16],'previous',1e16),
 ('original Linear counterexample','span_boundary',[-1.,1e16],[0.],'linear',1e16),
 ('age exact equality','age_boundary',[-1.,1e16+2],[0.],'previous',1.),
 ('age inside neighbor','age_boundary',[-1.,1e16+2],[-2.**-52],'previous',1.),
 ('age outside neighbor','age_boundary',[-1.,1e16+2],[2.**-52],'previous',1.),
 ('large age larger cap','age_boundary',[-1.,1e16+2],[1e16],'previous',math.nextafter(1e16,math.inf)),
 ('large age smaller cap','age_boundary',[-1.,1e16+2],[1e16],'previous',math.nextafter(1e16,0.)),
 ('large span larger cap','span_boundary',[-1.,1e16],[0.],'linear',math.nextafter(1e16,math.inf)),
 ('unit span equality','unit_span',[0.,1.],[.5],'linear',1.),
 ('unit span smaller cap','unit_span',[0.,1.],[.5],'linear',math.nextafter(1.,0.)),
 ('unit span larger cap','unit_span',[0.,1.],[.5],'linear',math.nextafter(1.,math.inf)),
 ('observations exempt','age_boundary',[-1.,1e16+2],[-1.,1e16+2],'linear',0.),
 ('old unrestricted mode','age_boundary',[-1.,1e16+2],[1e16],'previous',None),
 ('tiny age equality','tiny_span',[0.,1e-323],[5e-324],'previous',5e-324),
 ('tiny span over cap','tiny_span',[0.,1e-323],[5e-324],'linear',5e-324),
 ('tiny span equality','tiny_span',[0.,1e-323],[5e-324],'linear',1e-323),
]
results=[];total=0
for case_index,(name,fixture,times,grid,policy,cap) in enumerate(scenarios):
 file=fdir/(fixture+'.mf4');args=[str(file),','.join(map(repr,grid)),'v','1',policy]
 if cap is not None:args+=['--max-gap',repr(cap)]
 cp=subprocess.run(['node',str(exe),*args],capture_output=True);assert cp.returncode==0,cp.stderr
 text=cp.stdout.decode('utf-8');assert text.endswith('\r\n')
 if capture:(capture/f'{case_index:02d}-{fixture}-after.csv').write_bytes(cp.stdout)
 rows=list(csv.reader(io.StringIO(text,newline=''),strict=True))
 assert rows[0]==['start_ns','time_s','v [u]','v [u]__valid'] and len(rows)==len(grid)+1
 origin=str(struct.unpack_from('<Q',file.read_bytes(),136)[0]);expected=[]
 lo,hi=map(Fraction,times)
 for row,t in zip(rows[1:],grid):
  q=Fraction(t);exact=q in [lo,hi]
  distance=q-lo if policy=='previous' else hi-lo
  valid=lo<=q<=hi and (exact or cap is None or distance<=Fraction(cap))
  assert row[0]==origin and struct.pack('>d',float(row[1]))==struct.pack('>d',t)
  assert row[3]==str(valid).lower(),(name,row,distance,cap)
  if valid:
   value=Fraction(1) if policy=='previous' and q<hi else Fraction(2) if q==hi else Fraction(1)+(q-lo)/(hi-lo)
   assert math.isclose(float(row[2]),float(value),rel_tol=2e-15,abs_tol=0.)
  else:assert row[2]==''
  expected.append(valid);total+=1
 results.append({'name':name,'rows':len(grid),'valid':expected})
print(json.dumps({'status':'pass','csv_scenarios':len(results),'complete_rows':total,'compiled_export_sha256':hashlib.sha256(exe.read_bytes()).hexdigest(),'reference':'Exact Fraction comparison of literal binary64 endpoints, query and cap; Python strict csv; no product predicate copied','cases':results}))
