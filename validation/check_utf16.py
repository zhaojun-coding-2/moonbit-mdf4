"""Independent fixed UTF-16 sample receiver; only stdlib/original bytes/literals.

The actual existing inspector/exporter consume owned files. No product decoder,
encoder, current output, or reference generator supplies expected text/cells.
"""
import argparse
import csv
import hashlib
import io
import json
from pathlib import Path
import struct
import subprocess

ROOT=Path(__file__).resolve().parents[1]
FIXTURE=ROOT/"testdata/utf16.mf4"
FIXTURE_SHA="1c0a1b794f82f1bf47e9a0ce74282e0735999097f76d845590819c98c5b2b3fd"
TEXT=["A","龙🧪","","é,\"\nZ","月兔","12345678"]
UNITS=[[0x41],[0x9f99,0xd83e,0xddea],[],[0xe9,0x2c,0x22,0xa,0x5a],[0x6708,0x5154],[0x31,0x32,0x33,0x34,0x35,0x36,0x37,0x38]]
LE=[True,False,True,True,True,True]
BE=[True,True,True,False,True,True]
ORIGIN=str(2**64-1)
TIME=list(range(6))
CN={1:504,2:344}
OFFSET={1:8,2:26}
DATA=952
STRIDE=45


def sha(raw):return hashlib.sha256(raw).hexdigest()


def expected_inspect(index,texts):
    return {"name":"status LE" if index==1 else "status BE","unit":"state","raw":texts,"timestamps":TIME,"values":texts,"valid":LE if index==1 else BE}


def table(texts=TEXT,indices=(1,2)):
    columns=[]
    header=["start_ns","time_s"]
    for index in indices:
        label="le" if index==1 else "be"
        valid=LE if index==1 else BE
        h=label+" [state]"
        header.extend([h,h+"__valid"])
        columns.append({"channel":index,"label":label,"source_name":"status LE" if index==1 else "status BE","unit":"state","interpolation":"previous","value_header":h,"validity_header":h+"__valid","valid_rows":sum(valid),"invalid_rows":6-sum(valid),"valid_value_kinds":["label"]})
    rows=[]
    for i,text in enumerate(texts):
        cells=[ORIGIN,str(i)]
        for index in indices:
            valid=(LE if index==1 else BE)[i]
            cells.extend([text if valid else "",str(valid).lower()])
        rows.append(cells)
    buf=io.StringIO(newline="")
    writer=csv.writer(buf,quoting=csv.QUOTE_ALL,lineterminator="\r\n")
    writer.writerow(header);writer.writerows(rows)
    schema={"schema_version":"mdf4.analysis.schema/1","start_ns":ORIGIN,"row_count":6,"origin_header":"start_ns","time_header":"time_s","max_gap_seconds":None,"first_time":"0","last_time":"5","columns":columns}
    return buf.getvalue().encode(),schema,rows


CSV,SCHEMA,ROWS=table()
assert sha(CSV)=="391ba47666c632d625dadec75de48da06e5cd7caae6f60294e5477e7bbac7759"


def verify_original():
    raw=FIXTURE.read_bytes()
    assert sha(raw)==FIXTURE_SHA and len(raw)==1288
    assert raw[8:16]==b"4.11    " and struct.unpack_from("<H",raw,28)[0]==411
    assert struct.unpack_from("<Q",raw,136)[0]==2**64-1
    assert raw[504+88+2]==8 and raw[344+88+2]==9
    for i,units in enumerate(UNITS):
        at=DATA+i*STRIDE
        assert struct.unpack_from("<d",raw,at)[0]==i
        assert list(struct.unpack_from("<9H",raw,at+8))==units+[0]*(9-len(units))
        assert list(struct.unpack_from(">9H",raw,at+26))==units+[0]*(9-len(units))
        assert raw[at+44]==[0,1,0,2,0,0][i]
        assert raw[at+8:at+26].decode("utf-16-le").split("\0")[0]==TEXT[i]
        assert raw[at+26:at+44].decode("utf-16-be").split("\0")[0]==TEXT[i]
    return raw


def example(path):
    verify_original()
    actual=json.loads(path.read_text(encoding="utf-8"))
    schema=actual.pop("schema_json")
    assert json.loads(schema)==SCHEMA
    assert actual=={"version":"4.11","start_ns":ORIGIN,"raw_le":TEXT,"raw_be":TEXT,"values_le":TEXT,"values_be":TEXT,"timestamps":TIME,"valid_le":LE,"valid_be":BE,"window_le":["龙🧪",""],"window_valid":[False,True],"csv":CSV.decode()}
    print(json.dumps({"status":"pass","receiver":"public UTF16 example","rows":6,"rawStringsPerEndian":6,"csvSHA256":sha(CSV),"actualOutputSHA256":sha(path.read_bytes())}))


def files(inspector,exporter,out,baseline=None):
    out.mkdir(parents=True,exist_ok=False)
    original=verify_original()
    captures=[]
    owned={FIXTURE:sha(original)}

    def invoke(name,binary,args):
        cp=subprocess.run(["node",str(binary),*map(str,args)],cwd=ROOT,capture_output=True)
        stdout=out/(name+".stdout");stderr=out/(name+".stderr")
        stdout.write_bytes(cp.stdout);stderr.write_bytes(cp.stderr)
        captures.append({"name":name,"argv":["node",str(binary),*map(str,args)],"exit":cp.returncode,"stdout":str(stdout),"stderr":str(stderr),"stdoutSHA256":sha(cp.stdout),"stderrSHA256":sha(cp.stderr)})
        return cp

    def write(name,raw):
        path=out/(name+".mf4");path.write_bytes(raw);owned[path]=sha(raw)
        return path

    def inspect(name,path,index,texts=TEXT):
        cp=invoke(name,inspector,[path,"--index",index])
        assert cp.returncode==0 and cp.stderr==b"",(name,cp.stderr)
        want=expected_inspect(index,texts)
        assert json.loads(cp.stdout)==want,"Complete independent inspector mismatch: "+name
        captures[-1].update(stage="inspect_ok",expected=want)

    def export(name,path,indices=(1,2)):
        receipt=out/(name+".receipt.json")
        args=[]
        for index in indices:args.extend(["le" if index==1 else "be",str(index),"previous"])
        cp=invoke(name,exporter,[path,"0,1,2,3,4,5",*args,"--receipt",receipt])
        want,schema,rows=table(indices=indices)
        assert cp.returncode==0 and cp.stderr==b"" and cp.stdout==want,"Complete UTF16 CSV mismatch: "+name
        assert list(csv.reader(io.StringIO(cp.stdout.decode(),newline=""),strict=True))[1:]==rows
        source=path.read_bytes()
        expected={"receipt_version":"mdf4.analysis.receipt/1","source":{"sha256":sha(source),"bytes":len(source)},"csv":{"sha256":sha(want),"bytes":len(want),"encoding":"UTF-8","newline":"CRLF"},"table":schema}
        assert json.loads(receipt.read_text(encoding="utf-8"))==expected
        captures[-1].update(stage="export_ok",expectedRows=rows,expectedSchema=schema,receipt=str(receipt),receiptSHA256=sha(receipt.read_bytes()))

    cp=invoke("metadata",inspector,[FIXTURE])
    assert cp.returncode==0 and cp.stderr==b"" and json.loads(cp.stdout)=={"version":"4.11","start_ns":ORIGIN,"channels":["time","status LE","status BE"]}
    captures[-1]["stage"]="metadata_ok"
    for index in [1,2]:inspect("full-"+str(index),FIXTURE,index)
    export("full",FIXTURE)
    export("only-le",FIXTURE,(1,));export("only-be",FIXTURE,(2,))
    v410=bytearray(original);v410[8:16]=b"4.10    ";struct.pack_into("<H",v410,28,410)
    path=write("v410",v410)
    for index in [1,2]:inspect("v410-"+str(index),path,index)
    export("v410",path)

    def altered(index,payload,row=None,bits=144,offset=None):
        raw=bytearray(original)
        offset=OFFSET[index] if offset is None else offset
        struct.pack_into("<II",raw,CN[index]+88+4,offset,bits)
        for i in range(6) if row is None else [row]:
            at=DATA+i*STRIDE+offset
            size=bits//8
            raw[at:at+size]=payload.ljust(size,b"\0")[:size]
        return raw

    for index in [1,2]:
        endian="<" if index==1 else ">"
        variants=[("nul-padding",[0x41,0,0xd800],"A"),("bom-content",[0xfeff,0x41,0],"\ufeffA"),("whole-field",list(range(0x31,0x3a)),"123456789"),("minimum-pair",[0xd800,0xdc00,0],"\U00010000"),("maximum-pair",[0xdbff,0xdfff,0],"\U0010ffff")]
        for label,units,value in variants:
            payload=struct.pack(endian+"H"*len(units),*units)
            path=write(label+"-"+str(index),altered(index,payload))
            inspect(label+"-"+str(index),path,index,[value]*6)
        payload=struct.pack(endian+"HH",0x41,0)
        path=write("unaligned-"+str(index),altered(index,payload,bits=128,offset=OFFSET[index]+1))
        inspect("unaligned-"+str(index),path,index,["A"]*6)

    def reject(name,path,index,error,exact=False):
        cp=invoke(name+"-inspect",inspector,[path,"--index",index])
        assert cp.returncode!=0 and cp.stdout==b""
        assert cp.stderr.decode().startswith("channel error: ") and error in cp.stderr.decode(),(name,cp.stderr)
        if exact:assert cp.stderr.decode()=="channel error: "+error+"\n"
        captures[-1].update(stage="inspect_error",expectedError=error)
        receipt=out/(name+".receipt.json")
        cp=invoke(name+"-export",exporter,[path,"0,1,2,3,4,5","probe",index,"previous","--receipt",receipt])
        assert cp.returncode!=0 and cp.stdout==b"" and not receipt.exists()
        assert cp.stderr.decode().startswith("Cannot align channels: ") and error in cp.stderr.decode(),(name,cp.stderr)
        captures[-1].update(stage="export_error",expectedError=error)

    for index in [1,2]:
        endian="<" if index==1 else ">"
        broken=[("high",[0xd800]),("low",[0xdc00]),("high-bmp",[0xd800,0x41]),("high-nul",[0xd800,0]),("field-final-high",[0x41]*8+[0xd800])]
        for label,units in broken:
            # The lone-high sample is deliberately marked invalid in the source.
            row=(1 if index==1 else 3) if label=="high" else 0
            payload=struct.pack(endian+"H"*len(units),*units)
            if label in ["high","low"]:payload+=b"\0\0"
            path=write("broken-"+label+"-"+str(index),altered(index,payload,row=row))
            reject("broken-"+label+"-"+str(index),path,index,'CorruptedBlock("invalid UTF-16 sample")',exact=True)
        raw=bytearray(original);struct.pack_into("<I",raw,CN[index]+88+8,24)
        reject("odd-width-"+str(index),write("odd-width-"+str(index),raw),index,"InvalidBitField",exact=True)
        raw=bytearray(original);raw[CN[index]+88+3]=1
        reject("bit-offset-"+str(index),write("bit-offset-"+str(index),raw),index,"InvalidBitField",exact=True)
        raw=bytearray(original);struct.pack_into("<I",raw,CN[index]+88+4,43)
        reject("field-bound-"+str(index),write("field-bound-"+str(index),raw),index,"CorruptedBlock(")
    raw=bytearray(original);raw[CN[1]+88+2]=17
    reject("unhandled-type17",write("unhandled-type17",raw),1,'UnsupportedFeature("sample data type 17")',exact=True)
    for index in [1,2]:
        receipt=out/("numeric-linear-"+str(index)+".receipt.json")
        cp=invoke("numeric-linear-"+str(index),exporter,[FIXTURE,"0","probe",index,"linear","--receipt",receipt])
        assert cp.returncode!=0 and cp.stdout==b"" and not receipt.exists()
        assert 'InvalidTime("linear interpolation requires numeric values")' in cp.stderr.decode()
        captures[-1].update(stage="export_error",expectedError="Label is not numeric Linear input")

    # Independent old-type semantics plus exact base bytes, where supplied.
    core=(ROOT/"testdata/core-c0.mf4").read_bytes()
    def block(data,address):
        size,n=struct.unpack_from("<QQ",data,address+8)
        return list(struct.unpack_from("<"+"Q"*n,data,address+24)),address+24+8*n
    hd,hp=block(core,64);dg,_=block(core,hd[0]);cg,cgp=block(core,dg[1]);master,_=block(core,cg[1]);cn=master[0];_,cnp=block(core,cn);_,dtp=block(core,dg[2])
    size,invalid=struct.unpack_from("<II",core,cgp+24);stride=size+invalid
    offset=struct.unpack_from("<I",core,cnp+4)[0]
    times=[struct.unpack_from("<d",core,dtp+i*stride)[0] for i in range(6)]
    valid=[(core[dtp+i*stride+size]&1)==0 for i in range(6)]
    origin=str(struct.unpack_from("<Q",core,hp)[0])
    base_controls={item["name"]:item for item in json.loads(baseline.read_text(encoding="utf-8"))["legacyControls"]} if baseline else {}
    for name,dtype,payload,value,csv_value,kind in [("latin1",6,b"\xe9\xff\x00Z","éÿ","éÿ","label"),("utf8",7,b"\xc3\xa9\x00\xff","é","é","label"),("bytes",10,b"A\x00\xffZ",[65,0,255,90],"0x4100ff5a","data")]:
        raw=bytearray(core);raw[cnp+2]=dtype;struct.pack_into("<I",raw,cnp+8,32)
        for i in range(6):raw[dtp+i*stride+offset:dtp+i*stride+offset+4]=payload
        path=write("legacy-"+name,raw)
        cp=invoke("legacy-"+name+"-inspect",inspector,[path,"--index","1"])
        assert cp.returncode==0 and cp.stderr==b""
        observed=json.loads(cp.stdout)
        assert observed["values"]==[value]*6 and observed["timestamps"]==times and observed["valid"]==valid
        if dtype!=10:assert observed["raw"]==[value]*6
        if baseline:assert cp.stdout==Path(base_controls[name]["inspect"]).read_bytes()
        captures[-1].update(stage="legacy_inspect_ok",baselineBytesIdentical=bool(baseline))
        receipt=out/("legacy-"+name+".receipt.json")
        cp=invoke("legacy-"+name+"-export",exporter,[path,",".join(map(str,times)),"text","1","previous","--receipt",receipt])
        assert cp.returncode==0 and cp.stderr==b""
        expected_rows=[[origin,"0" if t==0 else str(t),csv_value if valid[i] else "",str(valid[i]).lower()] for i,t in enumerate(times)]
        buf=io.StringIO(newline="");w=csv.writer(buf,quoting=csv.QUOTE_ALL,lineterminator="\r\n");w.writerow(["start_ns","time_s","text [u]","text [u]__valid"]);w.writerows(expected_rows)
        assert cp.stdout==buf.getvalue().encode()
        r=json.loads(receipt.read_text(encoding="utf-8"))
        assert r["source"]=={"sha256":sha(raw),"bytes":len(raw)} and r["csv"]["sha256"]==sha(cp.stdout) and r["csv"]["bytes"]==len(cp.stdout)
        assert r["table"]["columns"][0]["valid_value_kinds"]==[kind]
        if baseline:
            assert cp.stdout==Path(base_controls[name]["export"]).read_bytes()
            assert receipt.read_bytes()==Path(base_controls[name]["receipt"]).read_bytes()
        captures[-1].update(stage="legacy_export_ok",receipt=str(receipt),receiptSHA256=sha(receipt.read_bytes()),baselineBytesIdentical=bool(baseline))
    assert all(sha(path.read_bytes())==value for path,value in owned.items())
    assert (ROOT/"testdata/core-c0.mf4").read_bytes()==core
    result={"status":"pass","case_count":len(captures),"positive_file_calls":sum(item["exit"]==0 for item in captures),"negative_file_calls":sum(item["exit"]!=0 for item in captures),"legacy_inspect_csv_receipt_controls":3,"baseline_controls_compared":len(base_controls),"originalSourceAndDerivedInputsUnchanged":True,"fixtureSHA256":FIXTURE_SHA,"mainCSV_SHA256":sha(CSV),"compiledInspectorSHA256":sha(inspector.read_bytes()),"compiledExporterSHA256":sha(exporter.read_bytes()),"cases":captures}
    (out/"manifest.json").write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({key:value for key,value in result.items() if key!="cases"}))


def main():
    parser=argparse.ArgumentParser();sub=parser.add_subparsers(dest="mode",required=True)
    ex=sub.add_parser("example");ex.add_argument("path",type=Path)
    fs=sub.add_parser("files");fs.add_argument("inspector",type=Path);fs.add_argument("exporter",type=Path);fs.add_argument("out",type=Path);fs.add_argument("--baseline",type=Path)
    args=parser.parse_args()
    if args.mode=="example":example(args.path)
    else:files(args.inspector.resolve(),args.exporter.resolve(),args.out.resolve(),args.baseline)


if __name__=="__main__":main()
