"""Own MIT exact gap-boundary fixtures; standard Python only."""
from pathlib import Path
import json,struct,hashlib
p=Path(__file__).resolve().parents[1]
base=(p/'analysis/fixture/roundtrip.mf4').read_bytes()
def block(b,a):
 l,n=struct.unpack_from('<QQ',b,a+8);return list(struct.unpack_from('<'+'Q'*n,b,a+24)),a+24+8*n,l-24-8*n
hd,_,_=block(base,64);dg,_,_=block(base,hd[0]);_,cg,_=block(base,dg[1]);_,dt,_=block(base,dg[2]);sz,iv=struct.unpack_from('<II',base,cg+24);stride=sz+iv
fixtures={}
for name,times in [('age_boundary',[-1.,10000000000000002.]),('span_boundary',[-1.,10000000000000000.]),('unit_span',[0.,1.]),('tiny_span',[0.,1e-323])]:
 b=bytearray(base)
 while len(b)%8:b.append(0)
 address=len(b);payload=bytearray(base[dt:dt+2*stride])
 for i,t in enumerate(times):struct.pack_into('<dd',payload,i*stride,t,float(i+1))
 b+=struct.pack('<4s4xQQ',b'##DT',24+len(payload),0)+payload
 struct.pack_into('<Q',b,hd[0]+24+16,address);struct.pack_into('<Q',b,cg+8,2)
 fixtures[name]=bytes(b)
# New test-only package: do not overwrite round-09 fixture files or generators.
fdir=p/'analysis/precision_fixture';fdir.mkdir(parents=True,exist_ok=True);(fdir/'moon.pkg').write_text('')
source=['// Own MIT MDF boundary fixtures; regeneration is in validation/generate_gap_precision.py\n'];manifest=[]
for name,b in fixtures.items():
 f=fdir/(name+'.mf4');f.write_bytes(b);manifest.append({'name':name,'sha256':hashlib.sha256(b).hexdigest(),'size':len(b)})
 source.append('\n///|\npub fn '+name+'() -> Bytes {\n  let parts : Array[Bytes] = [\n')
 for i in range(0,len(b),256):source.append('    b"'+''.join('\\x%02x'%v for v in b[i:i+256])+'",\n')
 source.append('  ]\n  let out : Array[Byte] = []\n  for part in parts { for byte in part { out.push(byte) } }\n  Bytes::from_array(out)\n}\n')
(fdir/'fixtures.mbt').write_text(''.join(source),encoding='utf-8');(fdir/'manifest.json').write_text(json.dumps({'source':'self-created roundtrip fixture, MIT; first two valid records retained','files':manifest},indent=2))
