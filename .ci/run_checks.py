"""Run real compiler/tests/consumers and retain bounded actionable CI diagnostics."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--target", choices=["js", "wasm-gc"], required=True)
    parser.add_argument("--results", type=Path, required=True)
    args = parser.parse_args()
    out = args.results.resolve()
    out.mkdir(parents=True, exist_ok=False)
    commands = []
    git = shutil.which("git")
    tracked = subprocess.check_output([git, "ls-files", "-z"], cwd=ROOT).decode().split("\0")
    before = {name: hashlib.sha256((ROOT/name).read_bytes()).hexdigest() for name in tracked if name}

    def run(name, command, cwd=ROOT, output=None):
        executable = shutil.which(str(command[0]))
        if not executable:
            raise RuntimeError("Required executable missing: "+str(command[0]))
        argv = [executable, *map(str, command[1:])]
        print("+ "+json.dumps([str(c) for c in command]), flush=True)
        cp = subprocess.run(argv, cwd=cwd, capture_output=True)
        (out/(name+".stdout")).write_bytes(cp.stdout)
        (out/(name+".stderr")).write_bytes(cp.stderr)
        commands.append({"name": name, "argv": argv, "cwd": str(cwd), "exit": cp.returncode})
        (out/"commands.json").write_text(json.dumps(commands, indent=2)+"\n", encoding="utf-8")
        if output:
            (out/output).write_bytes(cp.stdout)
        if cp.returncode:
            tail = (cp.stderr+cp.stdout).decode("utf-8", errors="replace")[-4000:]
            annotation = (name+" failed: "+tail).replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")
            print("::error title=MDF4 verification failed::"+annotation, flush=True)
            print(tail, flush=True)
            raise SystemExit(cp.returncode)
        if not output:
            print(cp.stdout.decode("utf-8", errors="replace"), end="", flush=True)
        if cp.stderr:
            print(cp.stderr.decode("utf-8", errors="replace"), end="", flush=True)
        return cp.stdout

    run("moon-version", ["moon", "version", "--all"])
    run("node-version", ["node", "--version"])
    run("python-version", [sys.executable, "--version"])
    run("format", ["moon", "fmt", "--check"])
    run("check", ["moon", "check", "--target", args.target])
    run("build", ["moon", "build", "--target", args.target])
    # No package filter: include analysis tests and the root numeric/layout tests.
    run("tests", ["moon", "test", "--target", args.target])
    run("raster-example", ["moon", "run", "example/raster", "--target", args.target], output="raster.json")
    run("receipt-example", ["moon", "run", "example/receipt", "--target", args.target], output="receipt.json")
    native = ROOT/"example/csv_consumer"
    run("native-check", ["moon", "check", "--target", args.target], cwd=native)
    run("native-example", ["moon", "run", ".", "--target", args.target], cwd=native, output="native.json")
    run("independent-examples", [sys.executable, ROOT/".ci/verify_examples.py", out])
    run("window-example", ["moon", "run", "example/window", "--target", args.target], output="window.json")
    run("independent-window-example", [sys.executable, ROOT/"validation/check_window.py", "example", out/"window.json"])
    run("query-example", ["moon", "run", "example/query", "--target", args.target], output="query.json")
    run("independent-query-example", [sys.executable, ROOT/"validation/check_query.py", "example", out/"query.json"])

    if args.target == "js":
        def artifact(name):
            candidates = [p for p in (ROOT/"_build/js/debug/build").rglob(name+".js")
                          if p.parent.name == name and p.parent.parent.name == "cmd"]
            if len(candidates) != 1:
                raise RuntimeError("Expected exactly one compiled "+name+" executable")
            return candidates[0]
        export, catalogue, summary, inspector = [artifact(name) for name in ["export", "channels", "summary", "inspect"]]
        receivers = [p for p in (ROOT/"_build/js/debug/build").rglob("window_receiver.js")
                     if p.parent.name == "window_receiver" and p.parent.parent.name == "validation"]
        if len(receivers) != 1:
            raise RuntimeError("Expected exactly one compiled public window receiver")
        window_receiver = receivers[0]
        consumers = [
            ("analysis", "check_analysis.py", [export]),
            ("gaps", "check_gaps.py", [export]),
            ("exact-gap", "check_gap_precision.py", [export, out/"gap-captures"]),
            ("receipts", "check_receipts.py", [export, out/"receipts"]),
            ("catalogue", "check_catalog.py", [catalogue, export, out/"catalogue"]),
            ("summary", "check_summary.py", [summary, catalogue, export, out/"summary"]),
            ("raster", "check_raster.py", [export, out/"raster-files"]),
            ("long-fields", "check_long_fields.py", [export, out/"long-fields"]),
            ("inspect", "check_inspect.py", [catalogue, inspector, out/"inspect"]),
            ("window", "check_window.py", ["files", window_receiver, out/"window-files"]),
            ("query", "check_query.py", ["files", export, out/"query-files"]),
        ]
        for name, filename, parameters in consumers:
            run("consumer-"+name, [sys.executable, ROOT/"validation"/filename, *parameters])

    head = subprocess.run([git, "rev-parse", "HEAD"], cwd=ROOT, capture_output=True)
    if os.environ.get("GITHUB_ACTIONS") == "true" and head.returncode:
        raise RuntimeError("CI source commit identity unavailable")
    files = [{"path": name, "sha256": hashlib.sha256((ROOT/name).read_bytes()).hexdigest()} for name in tracked if name]
    if {f["path"]: f["sha256"] for f in files} != before:
        raise RuntimeError("Verification modified tracked source files")
    artifacts = []
    for base in [ROOT/"_build", native/"_build"]:
        for path in sorted(base.rglob("*")):
            if path.is_file() and path.suffix in {".js", ".wasm"} and "test" not in str(path):
                artifacts.append({"path": path.relative_to(ROOT).as_posix(), "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "bytes": path.stat().st_size})
    manifest = {"commit": head.stdout.decode().strip() if head.returncode == 0 else None,
                "target": args.target, "files": files,
                "treeSha256": hashlib.sha256("\n".join(f["path"]+" "+f["sha256"] for f in files).encode()).hexdigest(),
                "commands": commands, "compiledArtifacts": artifacts, "trackedSourcesUnchanged": True, "status": "pass"}
    (out/"source-and-verification.json").write_text(json.dumps(manifest, indent=2)+"\n", encoding="utf-8")
    print(json.dumps({"status": "pass", "target": args.target, "commandCount": len(commands), "commit": manifest["commit"], "sourceTreeSha256": manifest["treeSha256"]}))
    print("::notice title=MDF4 verified source::target="+args.target+" commit="+str(manifest["commit"])+" source="+manifest["treeSha256"])
    query_suffix = ".js" if args.target == "js" else ".wasm"
    query_binaries = [p for p in (ROOT/("_build/"+args.target+"/debug/build")).rglob("query"+query_suffix)
                      if p.parent.name == "query" and p.parent.parent.name == "example"]
    if len(query_binaries) != 1:
        raise RuntimeError("Expected exactly one compiled public query example")
    print("::notice title=MDF4 verified query example::target="+args.target+" commit="+str(manifest["commit"])+" compiled="+hashlib.sha256(query_binaries[0].read_bytes()).hexdigest()+" output="+hashlib.sha256((out/"query.json").read_bytes()).hexdigest())
    if args.target == "js":
        print("::notice title=MDF4 verified exporter::commit="+str(manifest["commit"])+" sha256="+hashlib.sha256(export.read_bytes()).hexdigest())
        print("::notice title=MDF4 verified inspector::commit="+str(manifest["commit"])+" sha256="+hashlib.sha256(inspector.read_bytes()).hexdigest())
        print("::notice title=MDF4 verified window receiver::commit="+str(manifest["commit"])+" sha256="+hashlib.sha256(window_receiver.read_bytes()).hexdigest())
        query_files = out/"query-files/manifest.json"
        query_receipt = json.loads(query_files.read_text(encoding="utf-8"))
        print("::notice title=MDF4 verified query files::commit="+str(manifest["commit"])+" exporter="+hashlib.sha256(export.read_bytes()).hexdigest()+" manifest="+hashlib.sha256(query_files.read_bytes()).hexdigest()+" cases="+str(query_receipt["case_count"]))


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        message = str(error).replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")
        print("::error title=MDF4 verification failed::"+message, flush=True)
        raise
