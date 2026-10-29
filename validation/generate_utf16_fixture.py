"""Reproduce the own fixed-record UTF-16 sample in a fresh output directory.

No product encoder or third-party generator. Explicit hand code units and a
verbatim64-byte ID from the own core fixture; its program marker is historical,
not a claim that asammdf generated/validated these new blocks.
"""
import hashlib
import json
from pathlib import Path
import struct
import sys

ROOT=Path(__file__).resolve().parents[1]


def build():
    units=[[0x41],[0x9f99,0xd83e,0xddea],[],[0xe9,0x2c,0x22,0xa,0x5a],[0x6708,0x5154],[0x31,0x32,0x33,0x34,0x35,0x36,0x37,0x38]]
    masks=[0,1,0,2,0,0]
    def field(values,big):
        return struct.pack((">" if big else "<")+"H"*9,*(values+[0]*(9-len(values))))
    records=[struct.pack("<d",float(i))+field(value,False)+field(value,True)+bytes([masks[i]]) for i,value in enumerate(units)]
    raw=bytearray((ROOT/"testdata/core-c0.mf4").read_bytes()[:64])
    def append(tag,links,data):
        raw.extend(b"\0"*(-len(raw)%8));address=len(raw)
        raw.extend(struct.pack("<4s4xQQ",tag,24+8*len(links)+len(data),len(links)))
        if links:raw.extend(struct.pack("<"+"Q"*len(links),*links))
        raw.extend(data)
        return address
    hd=append(b"##HD",[0]*6,struct.pack("<Q",2**64-1)+b"\0"*24)
    def tx(text):
        data=text.encode()+b"\0";data+=b"\0"*(-len(data)%8)
        return append(b"##TX",[],data)
    names={text:tx(text) for text in ["time","s","status LE","status BE","state"]}
    def cn(name,unit,next_cn,kind,sync,dtype,offset,bits,flags=0,invalid=0):
        data=bytearray(72)
        struct.pack_into("<BBBBIIII",data,0,kind,sync,dtype,0,offset,bits,flags,invalid)
        return append(b"##CN",[next_cn,0,names[name],0,0,0,names[unit],0],data)
    be=cn("status BE","state",0,0,0,9,26,144,2,1)
    le=cn("status LE","state",be,0,0,8,8,144,2,0)
    master=cn("time","s",le,2,1,4,0,64)
    cg=append(b"##CG",[0,master,0,0,0,0],struct.pack("<QQHHIII",0,6,0,0,0,44,1))
    dt=append(b"##DT",[],b"".join(records))
    dg=append(b"##DG",[0,cg,dt,0],b"\0"*8)
    struct.pack_into("<Q",raw,hd+24,dg)
    return bytes(raw)


def main():
    if len(sys.argv)!=2:raise ValueError("Usage: generate_utf16_fixture.py NEW_OUTPUT_DIRECTORY")
    output=Path(sys.argv[1]);output.mkdir(parents=True,exist_ok=False)
    raw=build()
    assert hashlib.sha256(raw).hexdigest()=="1c0a1b794f82f1bf47e9a0ce74282e0735999097f76d845590819c98c5b2b3fd"
    (output/"utf16.mf4").write_bytes(raw)
    parts=["// Self-created MIT fixed-record UTF-16 fixture; validation/generate_utf16_fixture.py\n\n///|\npub fn utf16_0() -> Bytes {\n  let parts : Array[Bytes] = [\n"]
    for i in range(0,len(raw),256):parts.append('    b"'+''.join('\\x%02x'%byte for byte in raw[i:i+256])+'",\n')
    parts.append("  ]\n  let bytes : Array[Byte] = []\n  for part in parts { for value in part { bytes.push(value) } }\n  Bytes::from_array(bytes)\n}\n")
    (output/"utf16_fixture.mbt").write_text(''.join(parts),encoding="utf-8")
    print(json.dumps({"bytes":len(raw),"sha256":hashlib.sha256(raw).hexdigest(),"source":"Owned code units and standard-library struct; no asammdf runtime"}))


if __name__=="__main__":main()
