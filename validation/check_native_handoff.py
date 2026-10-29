"""Actual compiled public-API command -> saved files -> independent receiver.

Full expectations in native-handoff-cases.json are independent owned-byte/
literal oracles. Source ID/CC metadata comes from the original byte images;
no product output generates the expected samples.
"""
import argparse
import copy
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def wire(value):
    return (json.dumps(value, ensure_ascii=False, separators=(",", ":")) + "\n").encode()


def pin(raw):
    return {"bytes": str(len(raw)), "sha256": hashlib.sha256(raw).hexdigest()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("binary", type=Path)
    parser.add_argument("out", type=Path)
    args = parser.parse_args()
    binary, out = args.binary.resolve(), args.out.resolve()
    out.mkdir(parents=True, exist_ok=False)
    inputs = out / "inputs"
    inputs.mkdir()
    cases_path = ROOT / "validation/native-handoff-cases.json"
    cases = json.loads(cases_path.read_bytes())
    spec = importlib.util.spec_from_file_location("independent_saved_receiver", ROOT / "validation/verify_native_handoff.py")
    receiver = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(receiver)
    commands, passed, rejected = [], [], []
    before = {case["source"]: pin((ROOT/case["source"]).read_bytes()) for case in cases}

    def run(name, argv, env=None):
        cp = subprocess.run(list(map(str, argv)), cwd=ROOT, env=env, capture_output=True)
        (out/(name+".stdout")).write_bytes(cp.stdout)
        (out/(name+".stderr")).write_bytes(cp.stderr)
        commands.append({"name":name, "argv":list(map(str,argv)), "cwd":str(ROOT), "exit":cp.returncode,
                         "stdout":pin(cp.stdout), "stderr":pin(cp.stderr)})
        (out/"commands.json").write_bytes(wire(commands))
        return cp

    def receive(name, source, req, data, receipt, succeeds=True):
        cp = run(name+"-receiver", [sys.executable, "-B", ROOT/"validation/verify_native_handoff.py", source, req, data, receipt])
        if succeeds:
            assert cp.returncode == 0 and cp.stderr == b"", cp.stderr
            imported = receiver.verify(*(p.read_bytes() for p in [source,req,data,receipt]))
            assert json.loads(cp.stdout) == imported
            return imported
        assert cp.returncode != 0 and cp.stdout == b"" and cp.stderr, name
        try:
            receiver.verify(*(p.read_bytes() for p in [source,req,data,receipt]))
        except (ValueError, TypeError, UnicodeError):
            return
        raise AssertionError("imported receiver accepted " + name)

    # Freeze the exact successful and rejected request matrix before invocation.
    matrix = []
    for case in cases:
        raw = wire(case["request"])
        assert pin(raw) == case["requestBytes"] and pin(wire(case["expectedResult"])) == case["resultBytes"]
        request = inputs/(case["name"]+".request.json")
        request.write_bytes(raw)
        assert pin((ROOT/case["source"]).read_bytes()) == case["sourceIdentity"]
        matrix.append({"name":case["name"], "source":case["source"], "request":str(request), "bytes":pin(raw), "expected":"full literal success"})
    base = cases[0]
    bom_raw = b"\xef\xbb\xbf" + wire(base["request"]).replace(b'{"request_version":', b'{"request_version":"ignored earlier duplicate", "request_version":', 1)
    (inputs/"bom-duplicate.request.json").write_bytes(bom_raw)
    bad = []

    def bad_request(name, mutate, fragment, source=None):
        request = copy.deepcopy(base["request"])
        mutate(request)
        raw = wire(request)
        path = inputs/(name+".request.json")
        path.write_bytes(raw)
        bad.append((name, ROOT/(source or base["source"]), path, fragment))
        matrix.append({"name":name, "request":str(path), "bytes":pin(raw), "expected":"nonzero exit; empty stdout; absent receipt", "stderrContains":fragment})

    bad_request("source-hash", lambda r:r["source"].update(sha256="0"*64), "source identity mismatch")
    bad_request("source-size", lambda r:r["source"].update(bytes="1383"), "source identity mismatch")
    bad_request("group", lambda r:r["windows"][0].update(expected_group="0"), "window 0: expected_group mismatch")
    bad_request("global-index", lambda r:r["windows"][0].update(channel_index="4"), "ChannelNotFound")
    bad_request("later-range", lambda r:r["windows"].append({"channel_index":"1","expected_group":"0","start_record":"2","record_count":"1"}), "window 7: InvalidRange")
    bad_request("boolean-count", lambda r:r["windows"][0].update(record_count=True), "canonical nonnegative decimal string")
    bad_request("noncanonical-index", lambda r:r["windows"][0].update(channel_index="03"), "canonical nonnegative decimal string")
    bad_request("overflow", lambda r:r["windows"][0].update(start_record="2147483648"), "canonical nonnegative decimal string")
    bad_request("unknown-field", lambda r:r.update(sort=True), "request: invalid fields")
    bad_request("version", lambda r:r.update(request_version="mdf4.native-window.request/2"), "unsupported version")
    bad_request("record-budget", lambda r:r["windows"][0].update(record_count="1000001"), "handoff returned-record limit exceeded")
    bad_request("window-budget", lambda r:r.update(windows=[r["windows"][0]]*4097), "handoff window limit exceeded")
    def unsupported(r):
        r["source"] = pin((ROOT/"analysis/catalog_fixture/unsupported.mf4").read_bytes())
        r["windows"] = [{"channel_index":"1","expected_group":"0","start_record":"0","record_count":"0"}]
    bad_request("empty-metadata", unsupported, "UnsupportedConversion(99)", "analysis/catalog_fixture/unsupported.mf4")
    for name, raw, fragment in [("bad-utf8",b"\xff","native-handoff:"), ("bad-json",b"{","native-handoff:")]:
        request=inputs/(name+".request.json"); request.write_bytes(raw)
        bad.append((name,ROOT/base["source"],request,fragment))
        matrix.append({"name":name,"request":str(request),"bytes":pin(raw),"expected":"nonzero/empty stdout/absent receipt"})
    (out/"FROZEN-REQUEST-MATRIX.json").write_bytes(wire({"beforeFirstProductInvocation":True,"cases":matrix,"bomDuplicateRequest":pin(bom_raw)}))

    def success(case, name=None, raw=None, source=None, preload=None, env=None):
        name = name or case["name"]
        request = inputs/(name+".request.json")
        if raw is not None:
            request.write_bytes(raw)
        source = source or ROOT/case["source"]
        receipt, saved = out/(name+".receipt.json"), out/(name+".result.json")
        argv = ["node", *(["--require",preload] if preload else []), binary, source, request, "--receipt", receipt]
        cp = run(name,argv,env)
        assert cp.returncode == 0 and cp.stderr == b"", (name,cp.stderr)
        expected = wire(case["expectedResult"])
        assert cp.stdout == expected, "complete result mismatch: " + name
        saved.write_bytes(cp.stdout)
        expected_receipt = copy.deepcopy(case["expectedReceipt"])
        expected_receipt["request"] = pin(request.read_bytes())
        assert receipt.read_bytes() == wire(expected_receipt), "complete receipt mismatch: " + name
        # Snapshot test changes only its private path after loading. The receiver
        # is deliberately given the retained original byte image to bind.
        original = ROOT/case["source"]
        verified = receive(name,original,request,saved,receipt)
        passed.append({"name":name,"fullResult":pin(cp.stdout),"fullReceipt":pin(receipt.read_bytes()),"verified":verified})
        return request,saved,receipt

    baseline = None
    for case in cases:
        saved = success(case)
        if case["name"] == "multirate": baseline = saved
    success(base,"bom-duplicate",bom_raw)
    for name, source, request, fragment in bad:
        receipt=out/(name+".receipt.json")
        cp=run(name,["node",binary,source,request,"--receipt",receipt])
        assert cp.returncode != 0 and cp.stdout == b"" and fragment.encode() in cp.stderr and not receipt.exists(), name
        rejected.append(name)
    for name, argv in [("usage",[]),("missing-request",[ROOT/base["source"],inputs/"absent","--receipt",out/"missing.receipt.json"]),
                       ("missing-source",[inputs/"absent",baseline[0],"--receipt",out/"missing-source.receipt.json"])]:
        cp=run(name,["node",binary,*argv]);assert cp.returncode != 0 and cp.stdout == b"" and cp.stderr
        rejected.append(name)
    existing=out/"existing.receipt.json";existing.write_bytes(b"KEEP EXISTING RECEIPT\n")
    for name, receipt in [("receipt-exists",existing),("receipt-missing-parent",out/"no-parent/receipt.json")]:
        cp=run(name,["node",binary,ROOT/base["source"],baseline[0],"--receipt",receipt])
        assert cp.returncode != 0 and cp.stdout == b"" and cp.stderr
        rejected.append(name)
    assert existing.read_bytes() == b"KEEP EXISTING RECEIPT\n"

    # The first successful fs read returns original bytes, then changes only an
    # ephemeral source path. V8 coverage counts actual library open/read calls.
    seam_source=inputs/"snapshot.mf4";seam_source.write_bytes((ROOT/base["source"]).read_bytes())
    preload=out/"read-seam.cjs"
    preload.write_text("""const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const original=fs.readFileSync,counts={sourceReads:0,requestReads:0,loadedSHA256:null};
fs.readFileSync=function(p,...a){const b=original.call(this,p,...a);const f=path.resolve(String(p));
if(f===process.env.MDF_HANDOFF_SOURCE){counts.sourceReads++;counts.loadedSHA256=crypto.createHash('sha256').update(b).digest('hex');fs.writeFileSync(f,'changed after first loaded buffer');}
if(f===process.env.MDF_HANDOFF_REQUEST)counts.requestReads++;return b;};
process.on('exit',()=>fs.writeFileSync(process.env.MDF_HANDOFF_PROOF,JSON.stringify(counts)));
""",encoding="utf-8")
    env=dict(os.environ, MDF_HANDOFF_SOURCE=str(seam_source), MDF_HANDOFF_REQUEST=str(inputs/"snapshot.request.json"),
             MDF_HANDOFF_PROOF=str(out/"read-seam-proof.json"), NODE_V8_COVERAGE=str(out/"v8-coverage"))
    snap=success(base,"snapshot",wire(base["request"]),seam_source,preload,env)
    proof=json.loads((out/"read-seam-proof.json").read_bytes())
    assert proof=={"sourceReads":1,"requestReads":1,"loadedSHA256":base["sourceIdentity"]["sha256"]}
    assert seam_source.read_bytes() == b"changed after first loaded buffer"
    receive("changed-source",seam_source,*snap,succeeds=False)
    functions=[]
    for path in (out/"v8-coverage").glob("*.json"):
        coverage=json.loads(path.read_bytes())
        for script in coverage["result"]:
            if script["url"] == binary.as_uri(): functions.extend(script["functions"])
    # Pinned SDK's actual JS symbol spellings, discovered from the compiled
    # public functions before this first behavioral acceptance execution.
    opens=[f for f in functions if f["functionName"]=="_M0FP220zhaojun_2dcoding_2d24mdf44open"]
    reads=[f for f in functions if f["functionName"]=="_M0MP220zhaojun_2dcoding_2d24mdf47MdfFile12read__window"]
    assert len(opens)==1 and opens[0]["ranges"][0]["count"]==1, [(f['functionName'],f['ranges'][0]['count']) for f in functions if 'open' in f['functionName']]
    assert len(reads)==1 and reads[0]["ranges"][0]["count"]==7, [(f['functionName'],f['ranges'][0]['count']) for f in functions if 'read_window' in f['functionName']]
    (out/"one-loaded-image.json").write_bytes(wire({"status":"pass","filesystem":proof,"open":opens,"read_window":reads,"savedOriginalResult":pin(snap[1].read_bytes())}))

    # Rehash result bytes so these cases test protocol invariants beyond hashes.
    tampered=[]
    def tamper(name, change):
        result=copy.deepcopy(base["expectedResult"]);change(result)
        raw=wire(result);saved=out/(name+".result.json");saved.write_bytes(raw)
        receipt=copy.deepcopy(base["expectedReceipt"]);receipt["result"]={**pin(raw),"encoding":"UTF-8"}
        rec=out/(name+".receipt.json");rec.write_bytes(wire(receipt))
        receive(name,ROOT/base["source"],baseline[0],saved,rec,False);tampered.append(name)
    def reorder(r): r["windows"][0],r["windows"][1]=r["windows"][1],r["windows"][0]
    tamper("rehashed-order",reorder)
    tamper("rehashed-duplicate-loss",lambda r:r["windows"].pop(4))
    tamper("rehashed-invalid-loss",lambda r:r["windows"][1]["raw"].__setitem__(1,None))
    tamper("rehashed-overlap",lambda r:r["windows"][3]["values"][0].update(bits="0000000000000000"))
    tamper("rehashed-clock",lambda r:r["windows"][1]["time_bits"].__setitem__(1,"7ff0000000000000"))
    tamper("rehashed-metadata",lambda r:r["windows"][4].update(unit="wrong"))
    tamper("rehashed-untyped",lambda r:r["windows"][0]["raw"].__setitem__(0,"-99"))
    for name, slot in [("request-byte",0),("result-byte",1),("receipt-byte",2)]:
        paths=list(baseline);changed=out/(name+".json");changed.write_bytes(paths[slot].read_bytes()+b" ");paths[slot]=changed
        if name=="receipt-byte":
            # Receipt whitespace is legal and is not itself fingerprinted.
            receive(name,ROOT/base["source"],*paths)
        else:
            receive(name,ROOT/base["source"],*paths,succeeds=False);tampered.append(name)
    # A structurally consistent but semantically wrong unique sample remains
    # outside receiver proof. The independent full literal oracle detects it.
    false_value=copy.deepcopy(base["expectedResult"])
    false_value["windows"][6]["raw"][0]["bits"]="8000000000000000"
    false_raw=wire(false_value)
    assert false_raw != wire(base["expectedResult"])
    false_receipt=copy.deepcopy(base["expectedReceipt"]);false_receipt["result"]={**pin(false_raw),"encoding":"UTF-8"}
    assert receiver.verify((ROOT/base["source"]).read_bytes(),wire(base["request"]),false_raw,wire(false_receipt))["status"]=="pass"
    assert before == {path:pin((ROOT/path).read_bytes()) for path in before}
    manifest={"status":"pass","compiled":{ "path":str(binary),**pin(binary.read_bytes())},
              "oracle":{ "path":str(cases_path),**pin(cases_path.read_bytes())},"receiver":pin((ROOT/"validation/verify_native_handoff.py").read_bytes()),
              "success_cases":len(passed),"complete_results":passed,"command_failures":rejected,"receiver_tampering_rejections":tampered,
              "loadedImageProof":"one-loaded-image.json","semanticTruthBoundaryExercised":True,"originalInputsUnchanged":True,"commands":commands}
    (out/"manifest.json").write_bytes(wire(manifest))
    print(json.dumps({"status":"pass","success_cases":len(passed),"command_failures":len(rejected),"receiver_rejections":len(tampered)+1,
                      "node_calls":sum(c["argv"][0]=="node" for c in commands),"manifestSHA256":pin((out/"manifest.json").read_bytes())["sha256"]}))


if __name__ == "__main__":
    main()
