"""Independent saved-query public/example and actual CSV/receipt file receiver.

Only stdlib: literal cells/metadata, original input bytes, struct and CSV/hash
readback. The product and legacy CLI are never the expected-value oracle.
"""
import argparse
import copy
import csv
import hashlib
import io
import json
from pathlib import Path
import struct
import subprocess

ROOT = Path(__file__).resolve().parents[1]
ORIGIN = str(2**64-1)
MAIN_QUERY = {"query_version":"mdf4.analysis.query/1", "raster":["10.5","10.75","11.25","11.5"], "columns":[{"channel":"3","label":"state 🚦","policy":"previous"}], "max_gap_seconds":"0.25"}
MAIN_ROWS = [[ORIGIN,"10.5","前进","true"], [ORIGIN,"10.75","前进","true"], [ORIGIN,"11.25","","false"], [ORIGIN,"11.5","倒车","true"]]
INPUTS = {
    "calibrated": ("analysis/summary_fixture/calibrated.mf4", "1cbced8a512d91647d08ee37b566a230b67f96f4a0232bc37c9be78a21cf3e8c"),
    "mixed": ("analysis/review_fixture/mixed.mf4", "7bcd63e7f1aa923c5c1f2f97eebed1e767580efa8bdbcac365c4e35bf7072020"),
    "unsupported": ("analysis/catalog_fixture/unsupported.mf4", "dd0027b198095ab2ebb353f233b6a3d5c6126a0e9c87d59bf809f4026160cf8d"),
}


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def column(index, label, name, unit, policy, kind):
    header = label + (" ["+unit+"]" if unit else "")
    return {"channel":index,"label":label,"source_name":name,"unit":unit,"interpolation":policy,"value_header":header,"validity_header":header+"__valid","kind":kind}


def expected(query, rows, columns):
    header = ["start_ns","time_s"]
    shapes = []
    for index, source in enumerate(columns):
        c = dict(source)
        kind = c.pop("kind")
        n = sum(row[3+2*index] == "true" for row in rows)
        c.update(valid_rows=n,invalid_rows=len(rows)-n,valid_value_kinds=[kind] if n else [])
        shapes.append(c)
        header.extend([c["value_header"],c["validity_header"]])
    text = io.StringIO(newline="")
    writer = csv.writer(text,quoting=csv.QUOTE_ALL,lineterminator="\r\n")
    writer.writerow(header)
    writer.writerows(rows)
    schema = {"schema_version":"mdf4.analysis.schema/1","start_ns":ORIGIN,"row_count":len(rows),"origin_header":"start_ns","time_header":"time_s","max_gap_seconds":query["max_gap_seconds"],"first_time":query["raster"][0] if rows else None,"last_time":query["raster"][-1] if rows else None,"columns":shapes}
    return text.getvalue().encode("utf-8"), schema


MAIN_COLUMNS = [column(3,"state 🚦","速度🚲","m/s","previous","label")]
MAIN_CSV, MAIN_SCHEMA = expected(MAIN_QUERY, MAIN_ROWS, MAIN_COLUMNS)
assert sha(MAIN_CSV) == "a5c2742ea52e4176c1330ecf4da9e63e1f258d5048883592deb93290e744cc3e"


def verify_inputs():
    snapshots = {}
    for key,(relative,digest) in INPUTS.items():
        data = (ROOT/relative).read_bytes()
        assert sha(data) == digest, "Original owned input changed: "+key
        snapshots[key] = data
    # Directly inspect the original interleaved bytes, not a product read.
    raw = snapshots["calibrated"]
    address = raw.index(b"##DT")
    size, links = struct.unpack_from("<QQ",raw,address+8)
    assert address == 1208 and links == 0 and size == 72
    payload = raw[address+24:address+size]
    records = [struct.unpack_from("<BdhB",payload,i) for i in range(0,48,12)]
    assert records == [(7,0.0,-3,0),(9,0.25,42,0),(7,1.0,6,1),(9,0.75,-99,0)]
    assert [10+2*r[1] for r in records if r[0] == 9] == [10.5,11.5]
    return snapshots


def example(path):
    result = json.loads(path.read_text(encoding="utf-8"))
    assert set(result) == {"csv","schema_json","budget_error"}
    assert result["csv"].encode("utf-8") == MAIN_CSV
    assert json.loads(result["schema_json"]) == MAIN_SCHEMA
    assert result["budget_error"] is True
    print(json.dumps({"status":"pass","receiver":"public query example","rows":4,"valid":3,"invalid":1,"budget_error":True,"outputSHA256":sha(path.read_bytes()),"csvSHA256":sha(MAIN_CSV)}))


def files(binary, out, baseline=None):
    out.mkdir(parents=True,exist_ok=False)
    snapshots = verify_inputs()
    captures, query_hashes = [], {}

    def invoke(name, args, query_path=None):
        cp = subprocess.run(["node",str(binary),*map(str,args)],cwd=ROOT,capture_output=True)
        stdout, stderr = out/(name+".stdout"), out/(name+".stderr")
        stdout.write_bytes(cp.stdout)
        stderr.write_bytes(cp.stderr)
        captures.append({"name":name,"argv":["node",str(binary),*map(str,args)],"exit":cp.returncode,"stdout":str(stdout),"stderr":str(stderr),"stdoutSHA256":sha(cp.stdout),"stderrSHA256":sha(cp.stderr),"query":str(query_path) if query_path else None})
        return cp

    def document(name, obj, raw=None, bom=False):
        path = out/(name+".query.json")
        data = raw if raw is not None else json.dumps(obj,ensure_ascii=False).encode("utf-8")
        if bom:data=b"\xef\xbb\xbf"+data
        path.write_bytes(data)
        query_hashes[path] = sha(data)
        return path

    def accept(name, query, rows, columns, source="calibrated", bom=False):
        path = document(name,query,bom=bom)
        source_path = ROOT/INPUTS[source][0]
        receipt_path = out/(name+".receipt.json")
        cp = invoke(name,[source_path,"--query",path,"--receipt",receipt_path],path)
        want, schema = expected(query,rows,columns)
        assert cp.returncode == 0 and cp.stderr == b"", (name,cp.stderr)
        assert cp.stdout == want, "Complete hand CSV mismatch: "+name
        parsed = list(csv.reader(io.StringIO(cp.stdout.decode("utf-8"),newline=""),strict=True))
        assert parsed[1:] == rows
        receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
        assert receipt == {"receipt_version":"mdf4.analysis.receipt/1","source":{"sha256":sha(snapshots[source]),"bytes":len(snapshots[source])},"csv":{"sha256":sha(want),"bytes":len(want),"encoding":"UTF-8","newline":"CRLF"},"table":schema}, "Complete receipt mismatch: "+name
        captures[-1].update(stage="accepted",receipt=str(receipt_path),receiptSHA256=sha(receipt_path.read_bytes()),expectedRows=rows,expectedSchema=schema)
        return cp.stdout, receipt_path

    accepted = {}
    accepted["calibrated"] = accept("calibrated",MAIN_QUERY,MAIN_ROWS,MAIN_COLUMNS)
    no_gap = copy.deepcopy(MAIN_QUERY)
    no_gap["max_gap_seconds"] = None
    no_gap_rows = copy.deepcopy(MAIN_ROWS)
    no_gap_rows[2][2:] = ["前进","true"]
    accept("no-gap",no_gap,no_gap_rows,MAIN_COLUMNS)
    accept("bom",MAIN_QUERY,MAIN_ROWS,MAIN_COLUMNS,bom=True)
    empty = copy.deepcopy(MAIN_QUERY)
    empty["raster"] = []
    accept("empty",empty,[],MAIN_COLUMNS)
    label_query = copy.deepcopy(no_gap)
    label_query["columns"][0]["label"] = "--query"
    label_cols = [column(3,"--query","速度🚲","m/s","previous","label")]
    accepted["query-label"] = accept("query-label",label_query,no_gap_rows,label_cols)
    mixed = {"query_version":"mdf4.analysis.query/1","raster":["-0","0.25","1"],"columns":[{"channel":"0003","label":"bytes,\n\"🧪\"","policy":"previous"},{"channel":"1","label":"number","policy":"linear"},{"channel":"2","label":"--query","policy":"previous"}],"max_gap_seconds":None}
    mixed_cols = [column(3,"bytes,\n\"🧪\"","blob","u","previous","data"),column(1,"number","identity","u","linear","number"),column(2,"--query","state","u","previous","label")]
    mixed_rows = [[ORIGIN,"-0","0x000000000000f03f","true","1","true","1","true"],[ORIGIN,"0.25","0x000000000000f03f","true","1.25","true","1","true"],[ORIGIN,"1","0x0000000000000040","true","2","true","2","true"]]
    accepted["mixed"] = accept("mixed",mixed,mixed_rows,mixed_cols,source="mixed")
    reordered = dict(reversed(list(MAIN_QUERY.items())))
    accept("field-order",reordered,MAIN_ROWS,MAIN_COLUMNS)
    bare = ROOT/"example/query/request.json"
    assert json.loads(bare.read_text(encoding="utf-8")) == MAIN_QUERY
    query_hashes[bare] = sha(bare.read_bytes())
    cp = invoke("no-receipt",[ROOT/INPUTS["calibrated"][0],"--query",bare],bare)
    assert cp.returncode == 0 and cp.stderr == b"" and cp.stdout == MAIN_CSV
    captures[-1]["stage"] = "accepted_without_receipt"

    def reject(name, query=None, message=None, source="calibrated", raw=None, prefix=None, suffix=None, args=None, receipt=None):
        path = document(name,query,raw=raw) if args is None else None
        receipt = receipt or out/(name+".receipt.json")
        actual_args = args if args is not None else [ROOT/INPUTS[source][0],"--query",path,"--receipt",receipt]
        cp = invoke(name,actual_args,path)
        assert cp.returncode != 0 and cp.stdout == b"", "Failure produced success/partial CSV: "+name
        if message is not None:assert cp.stderr == (message+"\n").encode(), (name,cp.stderr)
        if prefix is not None:assert cp.stderr.decode().startswith(prefix), (name,cp.stderr)
        if suffix is not None:assert suffix in cp.stderr.decode(), (name,cp.stderr)
        if receipt.name != "protected.receipt.json":assert not receipt.exists(), "Failed query wrote receipt: "+name
        captures[-1].update(stage="rejected",expectedMessage=message,expectedPrefix=prefix,expectedSubstring=suffix)

    def invalid(name, obj=None, text=None, message=""):
        reject(name,obj,raw=text,message="Cannot execute query: InvalidRequest("+json.dumps(message,ensure_ascii=False)+")")

    for name,raw,detail in [("json-empty",b"","query document must be valid JSON"),("json-malformed",b"{","query document must be valid JSON"),("root-array",b"[]","query document must be an object"),("root-null",b"null","query document must be an object"),("double-bom",b"\xef\xbb\xbf\xef\xbb\xbf{}","query document must be valid JSON")]:
        invalid(name,text=raw,message=detail)
    q = copy.deepcopy(MAIN_QUERY);q["query_version"]="unknown"
    invalid("version",q,message="unsupported query version")
    q = copy.deepcopy(MAIN_QUERY);del q["max_gap_seconds"]
    invalid("missing-root",q,message="query fields must be query_version,raster,columns,max_gap_seconds")
    q = copy.deepcopy(MAIN_QUERY);q["source"]="not permitted"
    invalid("unknown-root",q,message="query fields must be query_version,raster,columns,max_gap_seconds")
    for name,value,detail in [("raster-root",None,"raster document must be an array of clock strings"),("raster-number",[10.5],"raster point 0 must be a clock string"),("raster-order",["11.5","10.5"],"raster clocks must be finite and strictly increasing"),("raster-rounded-duplicate",["10.5","10.50000000000000001"],"raster clocks must be finite and strictly increasing"),("raster-nan",["NaN"],"raster clocks must be finite and strictly increasing")]:
        q=copy.deepcopy(MAIN_QUERY);q["raster"]=value;invalid(name,q,message=detail)
    q=copy.deepcopy(MAIN_QUERY);q["columns"]=None
    invalid("columns-root",q,message="query columns must be an array")
    q=copy.deepcopy(MAIN_QUERY);q["columns"]=[None]
    invalid("column-object",q,message="query column 0 must be an object")
    q=copy.deepcopy(MAIN_QUERY);q["columns"][0]["unit"]="guess"
    invalid("column-unknown",q,message="query column 0 fields must be channel,label,policy")
    q=copy.deepcopy(MAIN_QUERY);del q["columns"][0]["label"]
    invalid("column-missing",q,message="query column 0 fields must be channel,label,policy")
    for field,value in [("channel",3),("channel",True),("label",False),("policy",None)]:
        q=copy.deepcopy(MAIN_QUERY);q["columns"][0][field]=value
        invalid("column-type-"+field+"-"+str(value),q,message="query column 0 channel,label,policy must be strings")
    for n,value in enumerate(["","-1","+3"," 3","３","2147483648","99999999999999999999"]):
        q=copy.deepcopy(MAIN_QUERY);q["columns"][0]["channel"]=value
        invalid("channel-lexical-"+str(n),q,message="query column 0 channel must be nonnegative decimal Int32")
    q=copy.deepcopy(MAIN_QUERY);q["columns"][0]["policy"]="nearest"
    invalid("policy",q,message="query column 0 policy must be previous or linear")
    for name,value,detail in [("gap-type",0.25,"max_gap_seconds must be a decimal string or null"),("gap-parse","no","invalid max_gap_seconds"),("gap-negative","-1","max_gap must be finite and nonnegative"),("gap-nonfinite","Infinity","max_gap must be finite and nonnegative")]:
        q=copy.deepcopy(MAIN_QUERY);q["max_gap_seconds"]=value;invalid(name,q,message=detail)
    q=copy.deepcopy(MAIN_QUERY);q["columns"]=[]
    invalid("empty-columns",q,message="select at least one channel")
    q=copy.deepcopy(MAIN_QUERY);q["columns"]*=2
    invalid("duplicate-label",q,message="column labels must be nonempty and unique")
    q=copy.deepcopy(MAIN_QUERY);q["columns"][0]["channel"]="2147483647"
    reject("source-index",q,prefix="Cannot execute query: Channel(",suffix='ChannelNotFound("2147483647")')
    q=copy.deepcopy(MAIN_QUERY);q["columns"][0]["policy"]="linear"
    reject("source-linear",q,prefix="Cannot execute query: Channel(",suffix='InvalidTime("linear interpolation requires numeric values")')
    q=copy.deepcopy(MAIN_QUERY);q["raster"]=[];q["columns"][0]["channel"]="1"
    reject("source-conversion-empty",q,source="unsupported",prefix="Cannot execute query: Channel(",suffix="UnsupportedConversion(99)")
    collision={"query_version":"mdf4.analysis.query/1","raster":["0"],"columns":[{"channel":"1","label":"held","policy":"previous"},{"channel":"9","label":"held [u]__valid","policy":"previous"}],"max_gap_seconds":None}
    reject("header-collision",collision,source="mixed",message='Cannot execute query: InvalidRequest("generated CSV headers must be unique")')

    good=document("io-good",MAIN_QUERY)
    malformed=document("io-malformed",None,raw=b"{")
    utf8=document("io-utf8",None,raw=b"\xc0\xaf")
    source=ROOT/INPUTS["calibrated"][0]
    missing=out/"missing.query.json"
    bad_source=out/"bad.mf4";bad_source.write_bytes(b"bad")
    reject("query-io",args=[source,"--query",missing],message="Cannot read query file")
    reject("query-directory",args=[source,"--query",out],message="Cannot read query file")
    reject("query-utf8",args=[source,"--query",utf8],message="Query file must be UTF-8")
    reject("io-before-open",args=[bad_source,"--query",missing],message="Cannot read query file")
    reject("utf8-before-open",args=[bad_source,"--query",utf8],message="Query file must be UTF-8")
    reject("open-before-json",args=[bad_source,"--query",malformed],prefix="Cannot open MDF input: ")
    reject("missing-source",args=[out/"missing.mf4","--query",good],prefix="Cannot open MDF input: ")
    usage="Usage: export FILE --query UTF8_JSON_FILE [--receipt NEW_PATH]"
    for name,tail in [("query-form-missing",[]),("query-form-extra",[good,"extra"]),("query-no-gap-override",[good,"--max-gap","0.25"]),("query-receipt-duplicate",[good,"--receipt","a","--receipt","b"])]:
        reject(name,args=[bad_source,"--query",*tail],message=usage)
    protected=out/"protected.receipt.json";protected.write_bytes(b"preserve existing receipt\n")
    reject("receipt-existing",args=[source,"--query",good,"--receipt",protected],receipt=protected,message="Could not create receipt; use a new writable path")
    reject("semantic-before-receipt",args=[source,"--query",malformed,"--receipt",protected],receipt=protected,message='Cannot execute query: InvalidRequest("query document must be valid JSON")')
    assert protected.read_bytes() == b"preserve existing receipt\n"

    # Old forms are compatibility controls, not expected-value oracles.
    grid=out/"legacy-grid.json";grid.write_text(json.dumps(MAIN_QUERY["raster"]),encoding="utf-8")
    legacy=[("calibrated",source,",".join(MAIN_QUERY["raster"]),["state 🚦","3","previous","--max-gap","0.25"]),
            ("query-label",source,"@"+str(grid),["--query","3","previous"]),
            ("mixed",ROOT/INPUTS["mixed"][0],"-0,0.25,1",["bytes,\n\"🧪\"","3","previous","number","1","linear","--query","2","previous"])]
    base_controls={item["name"]:item for item in json.loads(baseline.read_text(encoding="utf-8"))["controls"]} if baseline else {}
    for name,path,raster,tail in legacy:
        receipt=out/("legacy-"+name+".receipt.json")
        cp=invoke("legacy-"+name,[path,raster,*tail,"--receipt",receipt])
        assert cp.returncode == 0 and cp.stderr == b""
        want,query_receipt=accepted[name]
        assert cp.stdout == want and receipt.read_bytes() == query_receipt.read_bytes(), "New/legacy wire contract differs: "+name
        if baseline:
            assert cp.stdout == Path(base_controls[name]["stdout"]).read_bytes()
            assert receipt.read_bytes() == Path(base_controls[name]["receipt"]).read_bytes()
        captures[-1]["stage"]="legacy_compatible"
    assert all(sha(path.read_bytes()) == digest for path,digest in query_hashes.items())
    assert all((ROOT/INPUTS[key][0]).read_bytes() == data for key,data in snapshots.items())
    result={"status":"pass","case_count":len(captures),"query_successes":sum(c.get("stage","").startswith("accepted") for c in captures),"rejections":sum(c.get("stage")=="rejected" for c in captures),"legacy_controls":3,"baseline_controls_compared":len(base_controls),"sources_and_queries_unchanged":True,"compiled_exporter_sha256":sha(binary.read_bytes()),"main_csv_sha256":sha(MAIN_CSV),"original_input_hashes":{key:sha(data) for key,data in snapshots.items()},"cases":captures}
    (out/"manifest.json").write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({key:value for key,value in result.items() if key!="cases"}))


def main():
    parser=argparse.ArgumentParser()
    sub=parser.add_subparsers(dest="mode",required=True)
    ex=sub.add_parser("example");ex.add_argument("output",type=Path)
    fs=sub.add_parser("files");fs.add_argument("exporter",type=Path);fs.add_argument("out",type=Path);fs.add_argument("--baseline",type=Path)
    args=parser.parse_args()
    if args.mode=="example":example(args.output)
    else:files(args.exporter.resolve(),args.out.resolve(),args.baseline)


if __name__=="__main__":main()
