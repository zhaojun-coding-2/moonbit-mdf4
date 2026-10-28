"""Actual explicit raster-file export consumer, standard Python/Node only.

Usage: check_raster.py COMPILED_EXPORT_JS NEW_CAPTURE_DIRECTORY
"""
from pathlib import Path
import csv,hashlib,io,json,struct,subprocess,sys

p=Path(__file__).resolve().parents[1]
executable,out=map(lambda s:Path(s).resolve(),sys.argv[1:])
out.mkdir(parents=True,exist_ok=False)
source=p/'analysis/summary_fixture/calibrated.mf4'
origin=str(2**64-1)
grid=[repr(10.5+(i/4095.)**2) for i in range(4096)]
assert all(float(b)>float(a) for a,b in zip(grid,grid[1:]))
assert len(set(float(b)-float(a) for a,b in zip(grid,grid[1:])))>1
large=out/'大 栅格.json';large.write_text(json.dumps(grid)+'\n',encoding='utf-8')
small=p/'example/raster/grid.json'
small_grid=json.loads(small.read_text(encoding='utf-8'))
assert small_grid==['10.5','10.625','10.9','11.5']
bom=out/'零点 BOM.json';bom.write_bytes(b'\xef\xbb\xbf["-0"]\n')
empty=out/'empty.json';empty.write_text('[]\n',encoding='utf-8')

def invoke(name,args):
    args=['node',str(executable),*map(str,args)]
    assert len(subprocess.list2cmdline(args).encode('utf-16-le'))//2+1<32767
    cp=subprocess.run(args,capture_output=True)
    (out/(name+'.stdout')).write_bytes(cp.stdout);(out/(name+'.stderr')).write_bytes(cp.stderr)
    return cp

exports=[]
def export(name,file,points):
    receipt=out/(name+'.receipt.json')
    cp=invoke(name,[source,'@'+str(file),'state','3','previous','--receipt',receipt])
    assert cp.returncode==0 and cp.stderr==b'',cp.stderr
    rows=list(csv.reader(io.StringIO(cp.stdout.decode('utf-8'),newline=''),strict=True))
    assert rows[0]==['start_ns','time_s','state [m/s]','state [m/s]__valid']
    assert len(rows)==len(points)+1
    for i,(row,clock) in enumerate(zip(rows[1:],points)):
        assert len(row)==4 and row[0]==origin
        assert struct.pack('>d',float(row[1]))==struct.pack('>d',float(clock)),(i,row[1],clock)
        value=float(clock)
        if value<10.5 or value>11.5:expected=['','false']
        else:expected=['倒车' if value==11.5 else '前进','true']
        assert row[2:]==expected,(i,row,expected)
    saved=out/(name+'.csv');saved.write_bytes(cp.stdout)
    meta=json.loads(receipt.read_text(encoding='utf-8'))
    assert meta['table']['columns'][0]['channel']==3 and meta['table']['row_count']==len(points)
    assert meta['table']['first_time']==(rows[1][1] if points else None)
    assert meta['table']['last_time']==(rows[-1][1] if points else None)
    if name=='bom-zero':assert rows[1][1]=='-0'
    check=subprocess.run([sys.executable,str(p/'validation/verify_export.py'),str(source),str(saved),str(receipt)],capture_output=True)
    assert check.returncode==0,check.stderr
    result=json.loads(check.stdout);assert result['status']=='pass'
    (out/(name+'.verified.json')).write_bytes(check.stdout);exports.append(result)

export('large',large,grid)
export('small',small,small_grid)
export('bom-zero',bom,['-0'])
export('empty',empty,[])

bad_files=[]
for name,data in [('utf8',b'\xff'),('json',b'['),('shape',b'[0]'),('finite',b'["NaN"]'),
                  ('order',b'["11.5","10.5"]'),('duplicate',b'["0","-0"]')]:
    file=out/('bad-'+name+'.json');file.write_bytes(data);bad_files.append((name,file))
bad_files.append(('missing',out/'absent.json'))
for name,file in bad_files:
    receipt=out/('bad-'+name+'.receipt.json')
    cp=invoke('bad-'+name,[source,'@'+str(file),'state','3','previous','--receipt',receipt])
    assert cp.returncode!=0 and cp.stdout==b'' and cp.stderr.endswith(b'\n')
    assert not receipt.exists()

receipt=out/'budget.receipt.json'
args=[source,'@'+str(large)]
for i in range(500):args += ['c'+str(i),'3','previous']
args += ['--receipt',receipt]
cp=invoke('budget',args)
assert cp.returncode!=0 and cp.stdout==b'' and b'CellLimit' in cp.stderr and not receipt.exists()

print(json.dumps({'status':'pass','raster_file_exports':len(exports),'complete_csv_rows':sum(x['rows'] for x in exports),
                  'large_grid_points':len(grid),'large_clock_bit_checks':len(grid),'saved_receipts_verified_by_cli':len(exports),
                  'file_input_errors':len(bad_files),'unchanged_cell_budget_errors':1,'all_error_paths':len(bad_files)+1,
                  'large_grid_json_sha256':hashlib.sha256(large.read_bytes()).hexdigest(),
                  'compiled_export_sha256':hashlib.sha256(executable.read_bytes()).hexdigest(),
                  'reference':'Explicit nonuniform Python binary64 clock strings; every CSV row/time bit/mask/label; actual saved-byte verifier'}))
