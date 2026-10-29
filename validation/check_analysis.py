"""Independently validate the compiled Node CSV consumer using Python's csv module."""
from pathlib import Path
import subprocess,sys,csv,io,struct,json,hashlib
p=Path(__file__).resolve().parents[1]
exe=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else p/'_build/js/debug/build/zhaojun-coding-2/mdf4/cmd/export/export.js'
assert exe.is_file(),'Build cmd/export --target js or pass its compiled JS path'

def invoke(args):return subprocess.run(['node',str(exe),*map(str,args)],capture_output=True)
def rows(file,grid,selections):
 args=[file,grid,*selections];cp=invoke(args)
 assert cp.returncode==0,(args,cp.stderr.decode('utf-8'))
 text=cp.stdout.decode('utf-8');assert text.endswith('\r\n')
 result=list(csv.reader(io.StringIO(text,newline=''),strict=True))
 assert all(len(row)==2+2*(len(selections)//3) for row in result),result
 return result,text

def origin(file):return str(struct.unpack_from('<Q',Path(file).read_bytes(),136)[0])
def metadata(result,source,times):
 assert len(result)==len(times)+1
 for row,t in zip(result[1:],times):assert row[0]==origin(source) and float(row[1])==t

base=p/'testdata/unsorted.mf4';times=[0.,.25,.5,.75,1.];grid='0,0.25,0.5,0.75,1'
numeric,text=rows(base,grid,['held','1','previous','sensor','3','linear']);metadata(numeric,base,times)
assert numeric[0]==['start_ns','time_s','held','held__valid','sensor','sensor__valid']
expected=[('-3','true','','false'),('-3','true','42','true'),('-3','true','-28.5','true'),('-3','true','-99','true'),('','false','','false')]
assert [tuple(v[2:]) for v in numeric[1:]]==expected
special=p/'analysis/fixture/labels.mf4';alias='状态🚦,"列"\n第二行'
labels,text=rows(special,grid,['held','1','previous',alias,'3','previous']);metadata(labels,special,times)
assert labels[0]==['start_ns','time_s','held','held__valid',alias,alias+'__valid']
assert all(v[0]=='18446744073709551615' for v in labels[1:])
state='状态,"就绪"\n第二行';expected=[('','false'),(state,'true'),(state,'true'),('','true'),('','false')]
assert [tuple(v[4:]) for v in labels[1:]]==expected
binary_file=p/'analysis/fixture/binary.mf4';binary,text=rows(binary_file,grid,['payload','3','previous']);metadata(binary,binary_file,times)
assert [tuple(v[2:]) for v in binary[1:]]==[('','false'),('0x2a00','true'),('0x2a00','true'),('0x9dff','true'),('','false')]
nonfinite_file=p/'analysis/fixture/nonfinite.mf4';nonfinite,text=rows(nonfinite_file,'0,0.1,0.2',['IEEE','1','previous']);metadata(nonfinite,nonfinite_file,[0.,.1,.2])
assert nonfinite[0]==['start_ns','time_s','IEEE [u]','IEEE [u]__valid']
assert [tuple(v[2:]) for v in nonfinite[1:]]==[('NaN','true'),('Infinity','true'),('','false')]
empty,text=rows(base,'',['a','1','previous']);assert empty==[['start_ns','time_s','a','a__valid']]
errors=[[],[p/'analysis/fixture/absent.mf4','0','x','1','previous'],[base,'junk','x','1','previous'],[base,'0','x','oops','previous'],[base,'0','x','1','invalid'],[base,'0','x','-1','previous'],[special,'0.25','state','3','linear'],[base,'0','same','1','previous','same','3','previous'],[base,'0,0','x','1','previous'],[base,'0','time_s','1','previous']]
for args in errors:
 cp=invoke(args);assert cp.returncode!=0 and cp.stdout==b'' and cp.stderr.endswith(b'\n'),(args,cp.returncode,cp.stdout,cp.stderr)
print(json.dumps({'status':'pass','csv_cases':5,'data_rows':18,'error_cases':len(errors),'compiled_export_sha256':hashlib.sha256(exe.read_bytes()).hexdigest(),'reference':'Hand-specified two-clock values/masks and fixed literal payloads; Python csv strict parser; no product decoding algorithm copied'},ensure_ascii=False))
