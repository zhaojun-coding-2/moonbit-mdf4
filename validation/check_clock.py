"""Independent complete executable-guide and real native-clock file checks."""
import argparse
import csv
import hashlib
import io
import json
from pathlib import Path
import struct
import subprocess

ROOT=Path(__file__).resolve().parents[1]
CASES=ROOT/'validation/clock-cases.json'
def sha(raw):return hashlib.sha256(raw).hexdigest()
def bits(value):return struct.pack('>d',value).hex()
def value(hexadecimal):return struct.unpack('>d',bytes.fromhex(hexadecimal))[0]

def example(path):
 expected=[c['expected'] for c in json.loads(CASES.read_bytes())]
 actual=json.loads(path.read_bytes())
 assert actual==expected and len(actual)==3
 assert actual[0]['normalization']['seconds']==actual[1]['normalization']['seconds']
 assert actual[0]['normalization']['previous']==actual[1]['normalization']['previous']
 assert actual[0]['normalization']['linear']==actual[1]['normalization']['linear']
 assert actual[2]['normalization'] is None and actual[2]['native']['valid']==[True,False]
 print(json.dumps({'status':'pass','completePublicCases':3,'knownClockContracts':2,'unknownClockContracts':1,
                   'oracleSHA256':sha(CASES.read_bytes()),'outputSHA256':sha(path.read_bytes())}))

def files(inspector,exporter,out):
 out.mkdir(parents=True,exist_ok=False)
 cases=json.loads(CASES.read_bytes())[:2];commands=[];pins={}
 for case in cases:
  p=ROOT/case['source'];raw=p.read_bytes();identity=case['sourceIdentity']
  assert len(raw)==identity['bytes'] and sha(raw)==identity['sha256']
  pins[case['source']]={'path':str(p),'bytes':len(raw),'sha256':sha(raw)}
 (out/'inputs-pins.json').write_text(json.dumps({'inputs':pins,'oracleSHA256':sha(CASES.read_bytes())},indent=2)+'\n',encoding='utf-8')
 def invoke(name,binary,args):
  argv=['node',str(binary),*map(str,args)];cp=subprocess.run(argv,cwd=ROOT,capture_output=True)
  (out/(name+'.stdout')).write_bytes(cp.stdout);(out/(name+'.stderr')).write_bytes(cp.stderr)
  commands.append({'name':name,'argv':argv,'cwd':str(ROOT),'exit':cp.returncode,'stdoutSHA256':sha(cp.stdout),'stderrSHA256':sha(cp.stderr)})
  (out/'commands.json').write_text(json.dumps(commands,indent=2)+'\n',encoding='utf-8')
  assert cp.returncode==0 and cp.stderr==b'',(name,cp.stderr)
  return cp.stdout
 def inspect(case,index):
  p=case['expected'];master=index==p['master_index']
  actual=json.loads(invoke(case['name']+('-master' if master else '-signal'),inspector,[ROOT/case['source'],'--index',index]))
  assert set(actual)=={'name','unit','raw','timestamps','valid','values'}
  assert actual['name']==('time' if master else p['source_name'])
  assert actual['unit']==(p['master_unit'] if master else p['source_unit'])
  assert actual['raw']==(['0.25','0.75'] if master else ['42','-99'])
  assert actual['valid']==[True,True]
  assert list(map(bits,actual['timestamps']))==p['native']['times']
  assert list(map(bits,actual['values']))==(p['native']['times'] if master else p['native']['values'])
 def exported(case,grid,expected_values,label):
  raw=invoke(label,exporter,[ROOT/case['source'],','.join(map(str,grid)),'signal',3,'linear'])
  assert raw.count(b'\r\n')==4 and raw.endswith(b'\r\n')
  rows=list(csv.reader(io.StringIO(raw.decode('utf-8'),newline=''),strict=True))
  assert len(rows)==4 and rows[0]==['start_ns','time_s','signal [m/s]','signal [m/s]__valid']
  for row,time,number in zip(rows[1:],grid,expected_values):
   assert len(row)==4 and row[0]==case['expected']['start_ns'] and bits(float(row[1]))==bits(time)
   if number is None:assert row[2:]==['','false']
   else:assert bits(float(row[2]))==bits(number) and row[3]=='true'
 for case in cases:
  inspect(case,2);inspect(case,3)
  exported(case,case['native_grid'],[42.,-28.5,-99.],case['name']+'-native-export')
 exported(cases[0],[.75,1.,1.25],[None,None,None],'milliseconds-seconds-grid-export')
 assert len(commands)==7 and all(c['exit']==0 for c in commands)
 assert all(sha((ROOT/name).read_bytes())==pin['sha256'] for name,pin in pins.items())
 manifest={'status':'pass','actualNodeCalls':7,'completeInspectorObjects':4,'completeCSVExports':3,'completeCSVDataRows':9,
  'oracleSHA256':sha(CASES.read_bytes()),'commands':commands,'sources':pins,'sourcesUnchanged':True,
  'compiled':[{'path':str(p),'bytes':p.stat().st_size,'sha256':sha(p.read_bytes())} for p in [inspector,exporter]],
  'boundary':'Legacy time_s names are checked as unchanged output; they do not certify seconds or normalize a source clock.'}
 (out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
 print(json.dumps({'status':'pass','actualNodeCalls':7,'completeInspectorObjects':4,'completeCSVExports':3,'completeCSVDataRows':9,
                   'manifestSHA256':sha((out/'manifest.json').read_bytes())}))

def main():
 parser=argparse.ArgumentParser(description=__doc__);sub=parser.add_subparsers(dest='mode',required=True)
 p=sub.add_parser('example');p.add_argument('output',type=Path)
 p=sub.add_parser('files');p.add_argument('inspector',type=Path);p.add_argument('exporter',type=Path);p.add_argument('out',type=Path)
 args=parser.parse_args()
 if args.mode=='example':example(args.output.resolve())
 else:files(args.inspector.resolve(),args.exporter.resolve(),args.out.resolve())

if __name__=='__main__':main()
