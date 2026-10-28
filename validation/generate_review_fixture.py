"""Self-created mixed Value-kind MDF fixture for export review receipts."""
from pathlib import Path
import struct,json,hashlib
p=Path(__file__).resolve().parents[1];out=p/'analysis/review_fixture';out.mkdir(parents=True,exist_ok=True)
b=bytearray((p/'analysis/precision_fixture/unit_span.mf4').read_bytes())
base_sha=hashlib.sha256(b).hexdigest()
def block(a):
 l,n=struct.unpack_from('<QQ',b,a+8);return list(struct.unpack_from('<'+'Q'*n,b,a+24)),a+24+8*n,l-24-8*n
def txread(a):
 _,q,n=block(a);return b[q:q+n].split(b'\0')[0].decode()
def append(id,links,data):
 while len(b)%8:b.append(0)
 a=len(b);b.extend(struct.pack('<4s4xQQ',id,24+8*len(links)+len(data),len(links)))
 if links:b.extend(struct.pack('<'+'Q'*len(links),*links))
 b.extend(data);return a

def tx(s):
 data=s.encode()+b'\0';data+=b'\0'*((-len(data))%8);return append(b'##TX',[],data)
hd,hddata,_=block(64);dg,_,_=block(hd[0]);cg,_,_=block(dg[1]);addr=cg[1]
while addr:
 links,cnpos,cnsize=block(addr)
 if txread(links[2])=='identity':break
 addr=links[0]
else:raise AssertionError('identity missing')
original_links=list(links);original_data=bytes(b[cnpos:cnpos+cnsize]);next_cn=links[0]
label1,label2,default=tx('1'),tx('2'),tx('?')
ccdata=struct.pack('<BBHHHdd',7,0,0,3,2,0.,0.)+struct.pack('<dd',1.,2.)
cc=append(b'##CC',[0,0,0,0,label1,label2,default],ccdata)
blob_links=list(original_links);blob_links[0]=next_cn;blob_links[2]=tx('blob');blob_links[4]=0
blob_data=bytearray(original_data);blob_data[2]=10;blob_data[3]=0
blob=append(b'##CN',blob_links,blob_data)
state_links=list(original_links);state_links[0]=blob;state_links[2]=tx('state');state_links[4]=cc
state=append(b'##CN',state_links,original_data)
struct.pack_into('<Q',b,addr+24,state);struct.pack_into('<Q',b,hddata,2**64-1)
(out/'mixed.mf4').write_bytes(b);(out/'moon.pkg').write_text('')
parts=['// Self-created MIT mixed Value-kind fixture; validation/generate_review_fixture.py\n\n///|\npub fn mixed() -> Bytes {\n  let parts : Array[Bytes] = [\n']
for i in range(0,len(b),256):parts.append('    b"'+''.join('\\x%02x'%v for v in b[i:i+256])+'",\n')
parts.append('  ]\n  let bytes : Array[Byte] = []\n  for part in parts { for value in part { bytes.push(value) } }\n  Bytes::from_array(bytes)\n}\n')
(out/'fixtures.mbt').write_text(''.join(parts),encoding='utf-8')
(out/'manifest.json').write_text(json.dumps({'origin':'Own MIT unit_span fixture; same payload read as Number, enum Label, fixed Data; no vendor data','base_sha256':base_sha,'mixed_sha256':hashlib.sha256(b).hexdigest(),'channel_indices':{'time':0,'identity':1,'state':2,'blob':3},'source_values':{'identity':[1,2],'state':['1','2'],'blob_hex':['000000000000f03f','0000000000000040']},'relative_times':[0,1],'start_ns':str(2**64-1)},indent=2))
print(hashlib.sha256(b).hexdigest())
