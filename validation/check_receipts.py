"""Independent complete-row/hash/schema acceptance for opt-in export receipts."""
from pathlib import Path
import sys,subprocess,json,csv,io,hashlib,copy
from verify_export import verify
p=Path(__file__).resolve().parents[1]
exe=Path(sys.argv[1]).resolve();out=Path(sys.argv[2]).resolve();out.mkdir(parents=True,exist_ok=False)
source=p/'analysis/review_fixture/mixed.mf4';runs=[]
def invoke(file,grid,columns,options):return subprocess.run(['node',str(exe),str(file),grid,*columns,*options],capture_output=True)
def export(name,file,grid,columns,options=None):
 path=out/(name+'.receipt.json');opts=list(options or [])+['--receipt',str(path)]
 cp=invoke(file,grid,columns,opts);assert cp.returncode==0,cp.stderr
 receipt=json.loads(path.read_text(encoding='utf-8'));result=verify(file.read_bytes(),cp.stdout,receipt)
 (out/(name+'.csv')).write_bytes(cp.stdout);runs.append(result)
 return cp.stdout,receipt
numeric,nmeta=export('numeric',source,'0,1',['metric','1','previous'])
labels,lmeta=export('labels',source,'0,1',['metric','2','previous'])
assert numeric==labels
assert nmeta['source']==lmeta['source'] and nmeta['csv']==lmeta['csv']
assert nmeta['table']['columns'][0]['valid_value_kinds']==['number'] and lmeta['table']['columns'][0]['valid_value_kinds']==['label']
assert [nmeta['table']['columns'][0]['channel'],lmeta['table']['columns'][0]['channel']]==[1,2]
# A byte-identical old-mode CSV remains available with no new file side effect.
cp=invoke(source,'0,1',['metric','1','previous'],[]);assert cp.returncode==0 and cp.stdout==numeric
mixed,meta=export('mixed',source,'0,0.5,0.75,1',['number','1','linear','state','2','previous','bytes','3','previous'],['--max-gap','0.5'])
rows=list(csv.reader(io.StringIO(mixed.decode('utf-8'),newline=''),strict=True))
assert rows==[
 ['start_ns','time_s','number [u]','number [u]__valid','state [u]','state [u]__valid','bytes [u]','bytes [u]__valid'],
 ['18446744073709551615','0','1','true','1','true','0x000000000000f03f','true'],
 ['18446744073709551615','0.5','','false','1','true','0x000000000000f03f','true'],
 ['18446744073709551615','0.75','','false','','false','','false'],
 ['18446744073709551615','1','2','true','2','true','0x0000000000000040','true'],
]
assert meta['table']['max_gap_seconds']=='0.5'
assert [c['valid_rows'] for c in meta['table']['columns']]==[2,3,3]
assert [c['valid_value_kinds'] for c in meta['table']['columns']]==[['number'],['label'],['data']]
# Opposite tail-option order is accepted and produces the same CSV/schema.
other=out/'reverse.receipt.json';cp=invoke(source,'0,0.5,0.75,1',['number','1','linear','state','2','previous','bytes','3','previous'],['--receipt',str(other),'--max-gap','0.5'])
assert cp.returncode==0 and cp.stdout==mixed
reverse=json.loads(other.read_text(encoding='utf-8'));assert reverse==meta;verify(source.read_bytes(),cp.stdout,reverse);runs.append({'rows':4})
empty,emeta=export('empty',source,'',['state','2','previous'])
assert emeta['table']['row_count']==0 and emeta['table']['first_time'] is None and emeta['table']['last_time'] is None
assert emeta['table']['columns'][0]['valid_value_kinds']==[] and emeta['table']['start_ns']=='18446744073709551615'
missing,mmeta=export('missing',source,'2',['state','2','previous'])
assert mmeta['table']['columns'][0]['valid_value_kinds']==[]
utf8,umeta=export('unicode',source,'-0',['状态🚦,"列"\n第二行','2','previous'],['--max-gap','-0'])
assert umeta['table']['first_time']=='-0' and umeta['table']['max_gap_seconds']=='-0'
assert umeta['csv']['bytes']==len(utf8) and len(utf8)>len(utf8.decode('utf-8'))
nonfinite,nfmeta=export('nonfinite',p/'analysis/fixture/nonfinite.mf4','0,0.1,0.2',['IEEE','1','previous'])
assert nfmeta['table']['columns'][0]['valid_value_kinds']==['number']
# Controlled downstream changes must be detected against the saved receipt.
mutations=0
for changed_source,changed_csv in [(source.read_bytes()+b'\0',mixed),(source.read_bytes(),mixed.replace(b'\r\n',b'\n')),(source.read_bytes(),mixed.replace(b'"false"',b'"true"',1))]:
 try:verify(changed_source,changed_csv,meta)
 except ValueError:mutations+=1
 else:raise AssertionError('mutated bytes accepted')
wrong=copy.deepcopy(meta);wrong['table']['columns'][0]['valid_rows']+=1
try:verify(source.read_bytes(),mixed,wrong)
except ValueError:mutations+=1
else:raise AssertionError('wrong schema count accepted')
# Existing output paths are never overwritten and failed creation emits no CSV.
sentinel=out/'existing.json';sentinel.write_bytes(b'keep this exact file');old=sentinel.read_bytes()
failures=[['--receipt',str(sentinel)],['--receipt',str(out/'absent'/'r.json')],['--receipt'],['--receipt',str(out/'d1.json'),'--receipt',str(out/'d2.json')],['--max-gap','0.5','--max-gap','0.25']]
for options in failures:
 cp=invoke(source,'0',['metric','1','previous'],options)
 assert cp.returncode!=0 and cp.stdout==b'' and cp.stderr.endswith(b'\n'),(options,cp.stdout,cp.stderr)
assert sentinel.read_bytes()==old
assert not (out/'d1.json').exists() and not (out/'d2.json').exists()
# Labels matching either flag remain ordinary labels in positional triples.
for label in ['--receipt','--max-gap']:
 cp=invoke(source,'0',[label,'1','previous'],[]);assert cp.returncode==0,cp.stderr
 assert list(csv.reader(io.StringIO(cp.stdout.decode('utf-8'),newline='')))[0][2]==label+' [u]'
print(json.dumps({'status':'pass','receipt_exports':len(runs),'receipt_data_rows':sum(v['rows'] for v in runs),'mutations_rejected':mutations,'error_paths':len(failures),'old_flag_labels_preserved':2,'compiled_export_sha256':hashlib.sha256(exe.read_bytes()).hexdigest(),'reference':'Python standard csv/json/hashlib plus explicit complete-row expectations; independent asammdf fixture evidence'}))
