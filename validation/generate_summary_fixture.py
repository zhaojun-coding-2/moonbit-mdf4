"""Owned source-summary fixtures: calibrated enum, all-invalid and reversed clock."""
from pathlib import Path
import struct, json, hashlib

p = Path(__file__).resolve().parents[1]
out = p / 'analysis/summary_fixture'
out.mkdir(parents=True, exist_ok=True)
base = (p / 'analysis/catalog_fixture/catalog.mf4').read_bytes()
assert hashlib.sha256(base).hexdigest() == '2ce2e2a4492429d8ddc77947a72733102c2469dd4293a28fabd885c541605e0d'
b = bytearray(base)
def block(a):
    n = struct.unpack_from('<Q', b, a+16)[0]
    return list(struct.unpack_from('<'+'Q'*n, b, a+24)), a+24+8*n
def append(kind, links, payload):
    b.extend(b'\0'*(-len(b)%8)); a = len(b)
    b.extend(struct.pack('<4s4xQQ', kind, 24+8*len(links)+len(payload), len(links)))
    b.extend(struct.pack('<'+'Q'*len(links), *links)); b.extend(payload)
    return a
def tx(s):
    data = s.encode('utf-8')+b'\0'; data += b'\0'*(-len(data)%8)
    return append(b'##TX', [], data)
hd, _ = block(64); dg, dgpos = block(hd[0]); cg0, cg0pos = block(dg[1]); cg1, cg1pos = block(cg0[0])
master = cg1[1]; master_links, _ = block(master); signal = master_links[0]; _, signal_pos = block(signal)
reverse, forward, default = tx('倒车'), tx('前进'), tx('?')
cc = append(b'##CC', [0,0,0,0,reverse,forward,default], struct.pack('<BBHHHdd', 7,0,0,3,2,0.,0.)+struct.pack('<dd', -99.,42.))
struct.pack_into('<Q', b, signal+24+4*8, cc)
clock_cc = append(b'##CC', [0,0,0,0], struct.pack('<BBHHHdd', 1,0,0,0,2,0.,0.)+struct.pack('<dd', 10.,2.))
struct.pack_into('<Q', b, master+24+4*8, clock_cc)
calibrated = bytes(b)
flags = struct.unpack_from('<I', b, signal_pos+12)[0]
struct.pack_into('<I', b, signal_pos+12, flags|1); invalid = bytes(b)
b = bytearray(calibrated)
_, dtpos = block(dg[2]); dtlen = struct.unpack_from('<Q', b, dg[2]+8)[0]-24
assert b[dgpos] == 1 and b[dg[2]:dg[2]+4] == b'##DT'
groups = {}
for pos in [cg0pos, cg1pos]:
    size, n = struct.unpack_from('<II', b, pos+24)
    groups[struct.unpack_from('<Q', b, pos)[0]] = size+n
target_id = struct.unpack_from('<Q', b, cg1pos)[0]
positions=[]; pos=dtpos
while pos < dtpos+dtlen:
    rid=b[pos]; pos+=1
    if rid == target_id: positions.append(pos)
    pos += groups[rid]
assert [struct.unpack_from('<d',b,pos)[0] for pos in positions] == [.25,.75]
for pos,t in zip(positions,[.75,.25]): struct.pack_into('<d',b,pos,t)
files={'calibrated':calibrated,'all_invalid':invalid,'reversed':bytes(b)}
source=['// Self-created MIT source-summary fixtures; validation/generate_summary_fixture.py\n']
for name,data in files.items():
    (out/(name+'.mf4')).write_bytes(data)
    source.append('\n///|\npub fn '+name+'() -> Bytes {\n  let parts : Array[Bytes] = [\n')
    for i in range(0,len(data),256): source.append('    b"'+''.join('\\x%02x'%v for v in data[i:i+256])+'",\n')
    source.append('  ]\n  let bytes : Array[Byte] = []\n  for part in parts { for value in part { bytes.push(value) } }\n  Bytes::from_array(bytes)\n}\n')
(out/'fixtures.mbt').write_text(''.join(source),encoding='utf-8'); (out/'moon.pkg').write_text('',encoding='utf-8')
manifest={'origin':'MIT derivatives of own catalogue fixture; CC7 labels, CC1 clock, ALL_INVALID/reversed variants',
          'base_sha256':hashlib.sha256(base).hexdigest(),'index':3,'raw':[42,-99],'labels':['前进','倒车'],
          'physical_times':[10.5,11.5],'start_ns':str(2**64-1),
          'files':[{'name':name,'sha256':hashlib.sha256(data).hexdigest(),'bytes':len(data)} for name,data in files.items()]}
(out/'manifest.json').write_text(json.dumps(manifest,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
print(json.dumps(manifest))
