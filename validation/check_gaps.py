"""Independent file -> selection -> gap-limited table -> CSV consumer checks."""
from pathlib import Path
import subprocess,sys,csv,io,struct,json,hashlib
p=Path(__file__).resolve().parents[1]
exe=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else p/'_build/js/debug/build/zhaojun-coding-2/mdf4/cmd/export/export.js'
assert exe.is_file(),'Build cmd/export --target js or pass its compiled JS path'
rows_checked=0;cases_checked=0

def invoke(args):return subprocess.run(['node',str(exe),*map(str,args)],capture_output=True)
def export(file,grid,requests,gap=None):
 global rows_checked,cases_checked
 args=[file,grid,*requests]+([] if gap is None else ['--max-gap',str(gap)])
 cp=invoke(args);assert cp.returncode==0,cp.stderr
 text=cp.stdout.decode('utf-8');assert text.endswith('\r\n')
 rows=list(csv.reader(io.StringIO(text,newline=''),strict=True))
 assert all(len(row)==2+2*(len(requests)//3) for row in rows),rows
 origin=str(struct.unpack_from('<Q',Path(file).read_bytes(),136)[0])
 times=list(map(float,grid.split(','))) if grid else []
 assert len(rows)==len(times)+1
 for row,t in zip(rows[1:],times):assert row[0]==origin and struct.pack('>d',float(row[1]))==struct.pack('>d',t)
 rows_checked+=len(times);cases_checked+=1
 return rows,text
base=p/'testdata/unsorted.mf4';special=p/'analysis/fixture';grid='0,0.125,0.25,0.375,0.5,0.625,0.75,0.875,1'
requests=['held','1','previous','linear','3','linear']
rows,unrestricted=export(base,grid,requests)
expected=[('-3','true','','false'),('-3','true','','false'),('-3','true','42','true'),('-3','true','6.75','true'),('-3','true','-28.5','true'),('-3','true','-63.75','true'),('-3','true','-99','true'),('-3','true','','false'),('','false','','false')]
assert [tuple(row[2:]) for row in rows[1:]]==expected
rows,limited=export(base,grid,requests,.25)
expected=[('-3','true','','false'),('-3','true','','false'),('-3','true','42','true'),('','false','','false'),('','false','','false'),('','false','','false'),('','false','-99','true'),('','false','','false'),('','false','','false')]
assert [tuple(row[2:]) for row in rows[1:]]==expected
rows,_=export(base,'0.5',['linear','3','linear'],.5);assert rows[1][2:]==['-28.5','true']
state='状态,"就绪"\n第二行'
rows,_=export(special/'labels.mf4',grid,['state','3','previous'],0)
assert [tuple(row[2:]) for row in rows[1:]]==[('','false'),('','false'),(state,'true'),('','false'),('','false'),('','false'),('','true'),('','false'),('','false')]
rows,_=export(special/'labels.mf4',grid,['state','3','previous'],.25)
assert [tuple(row[2:]) for row in rows[1:]]==[('','false'),('','false'),(state,'true'),(state,'true'),(state,'true'),('','false'),('','true'),('','false'),('','false')]
rows,_=export(base,'0',['--max-gap','1','previous']);assert rows[0][2:] == ['--max-gap','--max-gap__valid'] and rows[1][2:]==['-3','true']
rows,_=export(base,'0.5',['--max-gap','1','previous'],.25);assert rows[1][2:]==['','false']
for name,expected in [('empty',[('','false'),('','false')]),('single',[('5e-324','true'),('','false')])]:
 rows,_=export(special/(name+'.mf4'),'0,0.125',['v','1','previous'],0)
 assert [tuple(row[2:]) for row in rows[1:]]==expected
rows,_=export(special/'wide_clock.mf4','-1.5e308,0,1.5e308',['held','0','previous','linear','0','linear'],1.6e308)
assert [tuple(row[3::2]) for row in rows[1:]]==[('true','true'),('true','false'),('true','true')]
rows,_=export(special/'roundtrip.mf4','-0,1,2,3,4,5',['value','1','previous'])
values=[5e-324,-0.,1e308,1e-310,-1e-310,float.fromhex('0x1.fffffffffffffp1023')]
bit_checks=6
for i,(row,value) in enumerate(zip(rows[1:],values)):
 if i==2:assert row[2:] == ['','false'];continue
 assert row[3]=='true' and struct.pack('>d',float(row[2]))==struct.pack('>d',value)
 bit_checks+=1
errors=[[base,'0','v','1','previous','--max-gap']]
errors += [[base,'0','v','1','previous','--max-gap',bad] for bad in ['abc','-1','inf','nan']]
errors += [[special/'labels.mf4','0.25','state','3','linear','--max-gap','0']]
for args in errors:
 cp=invoke(args);assert cp.returncode!=0 and cp.stdout==b'' and cp.stderr.endswith(b'\n'),(args,cp.stdout,cp.stderr)
print(json.dumps({'status':'pass','csv_cases':cases_checked,'data_rows':rows_checked,'signed_zero_and_finite_bit_checks':bit_checks,'error_cases':len(errors),'compiled_export_sha256':hashlib.sha256(exe.read_bytes()).hexdigest(),'reference':'Literal complete-row expectations; Python csv/struct; no product resampling logic copied'}))
