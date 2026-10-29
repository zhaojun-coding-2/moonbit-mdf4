"""Run real compiler/tests/consumers and retain bounded actionable CI diagnostics."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def module_name(folder):
    text = (folder/"moon.mod").read_text(encoding="utf-8")
    match = re.search(r'^name\s*=\s*"([^"]+)"\s*$', text, re.MULTILINE)
    if not match:
        raise RuntimeError("Module identity missing: "+str(folder))
    return match.group(1)


def package_binary(root, target, package):
    suffix = ".js" if target == "js" else ".wasm"
    binary = root/"_build"/target/"debug/build"/module_name(root)/package/(Path(package).name+suffix)
    if not binary.is_file():
        raise RuntimeError("Compiled package identity missing: "+str(binary))
    return binary


def public_consumer_identity(root, target, output):
    """Bind the real workspace consumer to its declared module/build identity."""
    native = root/"example/csv_consumer"
    library, consumer = module_name(root), module_name(native)
    suffix = ".js" if target == "js" else ".wasm"
    binary = native/"_build"/target/"debug/build"/consumer/(consumer.split("/")[-1]+suffix)
    if not binary.is_file():
        raise RuntimeError("Executed public consumer build identity missing: "+str(binary))
    return {"library": library, "consumer": consumer,
            "compiledPath": binary.relative_to(root).as_posix(),
            "compiledSHA256": hashlib.sha256(binary.read_bytes()).hexdigest(),
            "outputSHA256": hashlib.sha256(output.read_bytes()).hexdigest(),
            "behaviorGate": "native-check + native-example + independent-examples"}


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
    run("utf16-example", ["moon", "run", "example/utf16", "--target", args.target], output="utf16.json")
    run("independent-utf16-example", [sys.executable, ROOT/"validation/check_utf16.py", "example", out/"utf16.json"])
    run("consumer-record-newlines", [sys.executable, ROOT/"validation/check_record_newlines.py", out/"record-newlines"])

    if args.target == "js":
        def artifact(name):
            return package_binary(ROOT, "js", "cmd/"+name)
        export, catalogue, summary, inspector = [artifact(name) for name in ["export", "channels", "summary", "inspect"]]
        window_receiver = package_binary(ROOT, "js", "validation/window_receiver")
        native_handoff = package_binary(ROOT, "js", "cmd/native_handoff")
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
            ("utf16", "check_utf16.py", ["files", inspector, export, out/"utf16-files"]),
            ("native-handoff", "check_native_handoff.py", [native_handoff, out/"native-handoff-files"]),
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
    namespace = public_consumer_identity(ROOT, args.target, out/"native.json")
    manifest = {"commit": head.stdout.decode().strip() if head.returncode == 0 else None,
                "target": args.target, "files": files,
                "treeSha256": hashlib.sha256("\n".join(f["path"]+" "+f["sha256"] for f in files).encode()).hexdigest(),
                "commands": commands, "compiledArtifacts": artifacts, "publicConsumerNamespace": namespace,
                "trackedSourcesUnchanged": True, "status": "pass"}
    (out/"source-and-verification.json").write_text(json.dumps(manifest, indent=2)+"\n", encoding="utf-8")
    print(json.dumps({"status": "pass", "target": args.target, "commandCount": len(commands), "commit": manifest["commit"], "sourceTreeSha256": manifest["treeSha256"]}))
    print("::notice title=MDF4 verified source::target="+args.target+" commit="+str(manifest["commit"])+" source="+manifest["treeSha256"])
    print("::notice title=MDF4 verified namespace consumer::target="+args.target+" commit="+str(manifest["commit"])+" module="+namespace["library"]+" consumer="+namespace["consumer"]+" compiled="+namespace["compiledSHA256"]+" output="+namespace["outputSHA256"])
    newline_manifest = out/"record-newlines/manifest.json"
    newline_result = json.loads(newline_manifest.read_text(encoding="utf-8"))
    print("::notice title=MDF4 verified record newlines::target="+args.target+" commit="+str(manifest["commit"])+" verifier="+newline_result["verifier_sha256"]+" receiver="+newline_result["receiver_sha256"]+" fixture="+newline_result["fixture_sha256"]+" manifest="+hashlib.sha256(newline_manifest.read_bytes()).hexdigest()+" cases="+str(newline_result["case_count"])+" imports="+str(newline_result["imported_calls"]))
    query_binary = package_binary(ROOT, args.target, "example/query")
    print("::notice title=MDF4 verified query example::target="+args.target+" commit="+str(manifest["commit"])+" compiled="+hashlib.sha256(query_binary.read_bytes()).hexdigest()+" output="+hashlib.sha256((out/"query.json").read_bytes()).hexdigest())
    utf16_binary = package_binary(ROOT, args.target, "example/utf16")
    print("::notice title=MDF4 verified UTF16 example::target="+args.target+" commit="+str(manifest["commit"])+" compiled="+hashlib.sha256(utf16_binary.read_bytes()).hexdigest()+" output="+hashlib.sha256((out/"utf16.json").read_bytes()).hexdigest())
    if args.target == "js":
        print("::notice title=MDF4 verified exporter::commit="+str(manifest["commit"])+" sha256="+hashlib.sha256(export.read_bytes()).hexdigest())
        print("::notice title=MDF4 verified inspector::commit="+str(manifest["commit"])+" sha256="+hashlib.sha256(inspector.read_bytes()).hexdigest())
        print("::notice title=MDF4 verified window receiver::commit="+str(manifest["commit"])+" sha256="+hashlib.sha256(window_receiver.read_bytes()).hexdigest())
        query_files = out/"query-files/manifest.json"
        query_receipt = json.loads(query_files.read_text(encoding="utf-8"))
        print("::notice title=MDF4 verified query files::commit="+str(manifest["commit"])+" exporter="+hashlib.sha256(export.read_bytes()).hexdigest()+" manifest="+hashlib.sha256(query_files.read_bytes()).hexdigest()+" cases="+str(query_receipt["case_count"]))
        utf16_files = out/"utf16-files/manifest.json"
        utf16_receipt = json.loads(utf16_files.read_text(encoding="utf-8"))
        print("::notice title=MDF4 verified UTF16 files::commit="+str(manifest["commit"])+" inspector="+hashlib.sha256(inspector.read_bytes()).hexdigest()+" exporter="+hashlib.sha256(export.read_bytes()).hexdigest()+" manifest="+hashlib.sha256(utf16_files.read_bytes()).hexdigest()+" cases="+str(utf16_receipt["case_count"]))
        handoff_manifest = out/"native-handoff-files/manifest.json"
        handoff = json.loads(handoff_manifest.read_text(encoding="utf-8"))
        print("::notice title=MDF4 verified native handoff::commit="+str(manifest["commit"])+" compiled="+handoff["compiled"]["sha256"]+" oracle="+handoff["oracle"]["sha256"]+" receiver="+handoff["receiver"]["sha256"]+" manifest="+hashlib.sha256(handoff_manifest.read_bytes()).hexdigest()+" successes="+str(handoff["success_cases"])+" rejected="+str(len(handoff["command_failures"])))


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        message = str(error).replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")
        print("::error title=MDF4 verification failed::"+message, flush=True)
        raise
