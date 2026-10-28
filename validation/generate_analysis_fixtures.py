"""Generate project-owned analysis fixtures; standard Python only, never a runtime dependency."""
from pathlib import Path
import struct,json,hashlib,math
p=Path(__file__).resolve().parents[1]
out=p/'analysis/fixture';out.mkdir(parents=True,exist_ok=True)
def block(b,a):
 length,n=struct.unpack_from('<QQ',b,a+8);return list(struct.unpack_from('<'+'Q'*n,b,a+24)),a+24+8*n,length-24-8*n
def text(b,a):
 if not a:return ''
 _,q,n=block(b,a);return b[q:q+n].split(b'\0')[0].decode()
def channels(b):
 hd,_,_=block(b,64);dg,_,_=block(b,hd[0]);cg_addr=dg[1];result={}
 while cg_addr:
  cg,_,_=block(b,cg_addr);a=cg[1]
  while a:
   links,data,_=block(b,a);result[text(b,links[2])]=(a,data,links);a=links[0]
  cg_addr=cg[0]
 return result

def append(b,id,links,data):
 while len(b)%8:b.append(0)
 a=len(b);b+=struct.pack('<4s4xQQ',id,24+8*len(links)+len(data),len(links))
 if links:b+=struct.pack('<'+'Q'*len(links),*links)
 b+=data
 return a

def tx(b,s):
 data=s.encode()+b'\0';data+=b'\0'*((-len(data))%8);return append(b,b'##TX',[],data)

b=bytearray((p/'testdata/unsorted.mf4').read_bytes());cn,cndata,links=channels(b)['g1']
first=tx(b,'状态,"就绪"\n第二行');second=tx(b,'');default=tx(b,'未知')
params=struct.pack('<BBHHHdd',7,0,0,3,2,0.,0.)+struct.pack('<dd',42.,-99.)
cc=append(b,b'##CC',[0,0,0,0,first,second,default],params)
struct.pack_into('<Q',b,cn+24+4*8,cc);struct.pack_into('<Q',b,cn+24+6*8,0)
_,hddata,_=block(b,64);struct.pack_into('<Q',b,hddata,2**64-1)
fixtures={'labels':bytes(b)}
b=bytearray((p/'testdata/unsorted.mf4').read_bytes());cn,cndata,_=channels(b)['g1'];b[cndata+2]=10;b[cndata+3]=0;struct.pack_into('<I',b,cndata+8,16);struct.pack_into('<Q',b,cn+24+4*8,0)
fixtures['binary']=bytes(b)
b=bytearray((p/'testdata/core-c0.mf4').read_bytes());cn,cndata,_=channels(b)['identity'];b[cndata+2]=4;b[cndata+3]=0;struct.pack_into('<II',b,cndata+4,8,64)
hd,_,_=block(b,64);dg,_,_=block(b,hd[0]);_,cgdata,_=block(b,dg[1]);_,dt,_=block(b,dg[2]);size,invalid=struct.unpack_from('<II',b,cgdata+24)
for i,x in enumerate([math.nan,math.inf,-math.inf,1.,2.,3.]):struct.pack_into('<d',b,dt+i*(size+invalid)+8,x)
fixtures['nonfinite']=bytes(b)
source=['// Self-created MIT analysis fixtures; regenerate with validation/generate_analysis_fixtures.py\n']
manifest=[]
for name,data in fixtures.items():
 f=out/(name+'.mf4');f.write_bytes(data);manifest.append({'name':name,'sha256':hashlib.sha256(data).hexdigest(),'size':len(data)})
 source.append('\n///|\npub fn '+name+'() -> Bytes {\n  let parts : Array[Bytes] = [\n')
 for i in range(0,len(data),256):source.append('    b"'+''.join('\\x%02x'%v for v in data[i:i+256])+'",\n')
 source.append('  ]\n  let bytes : Array[Byte] = []\n  for part in parts { for value in part { bytes.push(value) } }\n  Bytes::from_array(bytes)\n}\n')
(out/'fixtures.mbt').write_text(''.join(source),encoding='utf-8')
(out/'moon.pkg').write_text('',encoding='utf-8')
(out/'manifest.json').write_text(json.dumps({'origin':'Own artificial core-c0/unsorted fixtures extended for table/CSV semantics; MIT; no vendor data','files':manifest},indent=2),encoding='utf-8')
print(json.dumps(manifest))
