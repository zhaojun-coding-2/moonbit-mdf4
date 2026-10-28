"""Additional owned gap/roundtrip fixtures, independent of the runtime reader."""
from pathlib import Path
import json,struct,hashlib
p=Path(__file__).resolve().parents[1];out=p/'analysis/fixture'
base=(out/'nonfinite.mf4').read_bytes()
assert hashlib.sha256(base).hexdigest()=='27c487babf7e58d0519ddb38ff1ba54ab3213773e723865b6159d9973e00bde0'
def block(b,a):
 l,n=struct.unpack_from('<QQ',b,a+8);return list(struct.unpack_from('<'+'Q'*n,b,a+24)),a+24+8*n,l-24-8*n
hd,_,_=block(base,64);dg,_,_=block(base,hd[0]);_,cg,_=block(base,dg[1]);_,dt,_=block(base,dg[2]);size,invalid=struct.unpack_from('<II',base,cg+24)
values=[5e-324,-0.,1e308,1e-310,-1e-310,float.fromhex('0x1.fffffffffffffp1023')]
fixtures={}
for name,times in [('roundtrip',[-0.,1.,2.,3.,4.,5.]),('wide_clock',[-1.7e308,-1.6e308,-1.5e308,1.5e308,1.6e308,1.7e308])]:
 b=bytearray(base)
 for i,(t,v) in enumerate(zip(times,values)):struct.pack_into('<dd',b,dt+i*(size+invalid),t,v)
 fixtures[name]=bytes(b)
for name,count in [('empty',0),('single',1)]:
 b=bytearray(fixtures['roundtrip'])
 while len(b)%8:b.append(0)
 address=len(b);payload=base[dt:dt+count*(size+invalid)]
 # First roundtrip record carries a finite subnormal value and negative zero clock.
 if count:payload=fixtures['roundtrip'][dt:dt+count*(size+invalid)]
 b+=struct.pack('<4s4xQQ',b'##DT',24+len(payload),0)+payload
 struct.pack_into('<Q',b,hd[0]+24+2*8,address);struct.pack_into('<Q',b,cg+8,count)
 fixtures[name]=bytes(b)
source=['// Additional self-created MIT fixtures; validation/generate_gap_fixtures.py\n'];manifest=[]
for name,data in fixtures.items():
 (out/(name+'.mf4')).write_bytes(data);manifest.append({'name':name,'sha256':hashlib.sha256(data).hexdigest(),'size':len(data)})
 source.append('\n///|\npub fn '+name+'() -> Bytes {\n  let parts : Array[Bytes] = [\n')
 for i in range(0,len(data),256):source.append('    b"'+''.join('\\x%02x'%v for v in data[i:i+256])+'",\n')
 source.append('  ]\n  let bytes : Array[Byte] = []\n  for part in parts { for value in part { bytes.push(value) } }\n  Bytes::from_array(bytes)\n}\n')
(out/'gaps.mbt').write_text(''.join(source),encoding='utf-8');(out/'gap-manifest.json').write_text(json.dumps({'origin':'Own MIT analysis/nonfinite fixture; no vendor data','files':manifest},indent=2))
print(json.dumps(manifest))
