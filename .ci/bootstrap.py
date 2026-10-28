"""Checksum-pinned private SDK/dependency setup, without registry/global writes."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import sys
import tarfile
import time
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def digest(data):
    return hashlib.sha256(data).hexdigest()


def download(item, cache):
    cache.mkdir(parents=True, exist_ok=True)
    target = cache/item["file"]
    if not target.exists():
        for attempt in range(3):
            try:
                request = urllib.request.Request(item["url"], headers={"User-Agent": "moonbit-mdf4-ci"})
                with urllib.request.urlopen(request, timeout=90) as response:
                    data = response.read()
                if digest(data) != item["sha256"]:
                    raise ValueError("Checksum mismatch for "+item["file"])
                target.write_bytes(data)
                break
            except (OSError, TimeoutError):
                if attempt == 2:
                    raise
                time.sleep(2**attempt)
    if digest(target.read_bytes()) != item["sha256"]:
        raise ValueError("Cached checksum mismatch for "+item["file"])
    return target


def extract(archive, destination, strip_root=False):
    destination.mkdir(parents=True, exist_ok=True)
    if archive.name.endswith(".zip"):
        with zipfile.ZipFile(archive) as source:
            if source.testzip() is not None:
                raise ValueError("ZIP CRC failure")
            for item in source.infolist():
                parts = Path(item.filename).parts
                if strip_root:
                    parts = parts[1:]
                if not parts or item.is_dir():
                    continue
                rel = Path(*parts)
                if rel.is_absolute() or ".." in rel.parts:
                    raise ValueError("Unsafe archive path")
                output = destination/rel
                output.parent.mkdir(parents=True, exist_ok=True)
                output.write_bytes(source.read(item))
    else:
        with tarfile.open(archive, "r:gz") as source:
            source.extractall(destination, filter="data")


def sdk(args):
    home = args.sdk_dir.resolve()
    if home == (Path.home()/".moon").resolve():
        raise ValueError("Use a private SDK directory, not the global MoonBit home")
    lock = json.loads((ROOT/".ci/toolchain.json").read_text())
    platform = "windows" if sys.platform == "win32" else "linux"
    selected = lock["platforms"][platform]
    extract(download(selected["sdk"], args.cache_dir), home)
    extract(download(selected["core"], args.cache_dir), home/"lib")
    if platform == "windows" and not (home/"bin/moonx.exe").exists():
        os.link(home/"bin/moon.exe", home/"bin/moonx.exe")
    print(json.dumps({"privateSdk": str(home), "version": lock["version"], "archives": selected}))


def dependencies(args):
    lock = json.loads((ROOT/".ci/dependencies.json").read_text())
    args.deps_dir.mkdir(parents=True, exist_ok=True)
    members = [str(ROOT)]
    native = None
    records = []
    for item in lock:
        if item.get("optionalNativeConsumer") and not args.include_native:
            continue
        destination = args.deps_dir/(item["module"].replace("/", "--")+"-"+item["sha256"][:12])
        extract(download(item, args.cache_dir), destination, item.get("stripRoot", False))
        manifest = (destination/"moon.mod").read_text(encoding="utf-8")
        for key in ["name", "version"]:
            expected = item["module"] if key == "name" else item["version"]
            if not re.search(r'^'+key+r'\s*=\s*"'+re.escape(expected)+r'"\s*$', manifest, re.MULTILINE):
                raise ValueError("Unexpected module identity: "+item["module"])
        if item.get("optionalNativeConsumer"):
            native = destination
            pin = json.loads((ROOT/"example/csv_consumer/DEPENDENCY.json").read_text())
            changed_endings = []
            for entry in pin["files"]:
                path = destination/entry["path"]
                original = path.read_bytes()
                if digest(original) != entry["sha256"]:
                    # Reproduce the recorded Windows checkout's line endings,
                    # only when the exact recorded source hash proves identity.
                    materialized = original.replace(b"\r\n", b"\n").replace(b"\n", b"\r\n")
                    if digest(materialized) != entry["sha256"]:
                        raise ValueError("Pinned NyaCSV source mismatch: "+entry["path"])
                    path.write_bytes(materialized)
                    changed_endings.append(entry["path"])
            records.append({"module": item["module"], "version": item["version"], "archiveSha256": item["sha256"],
                            "commit": pin["commit"], "recordedSourceHashesMatched": len(pin["files"]), "lineEndingsMaterialized": changed_endings})
        else:
            members.append(str(destination.resolve()))
            records.append({"module": item["module"], "version": item["version"], "archiveSha256": item["sha256"]})
    def workspace(paths):
        return "members = [\n"+"".join("  "+json.dumps(path)+",\n" for path in paths)+"]\n"
    (ROOT/"moon.work").write_text(workspace(members), encoding="utf-8", newline="\n")
    if native:
        example = ROOT/"example/csv_consumer"
        (example/"moon.work").write_text(workspace(members+[str(example), str(native.resolve())]), encoding="utf-8", newline="\n")
    resolution = {"modules": records, "rootMembers": members, "nativeConsumerEnabled": native is not None,
                  "registryResolutionUsed": False, "rootManifestChanged": False}
    (args.deps_dir/"resolution.json").write_text(json.dumps(resolution, indent=2)+"\n", encoding="utf-8")
    print(json.dumps(resolution))


def main():
    parser = argparse.ArgumentParser()
    commands = parser.add_subparsers(dest="command", required=True)
    one = commands.add_parser("sdk")
    one.add_argument("--sdk-dir", type=Path, required=True)
    one.add_argument("--cache-dir", type=Path, required=True)
    two = commands.add_parser("deps")
    two.add_argument("--deps-dir", type=Path, required=True)
    two.add_argument("--cache-dir", type=Path, required=True)
    two.add_argument("--include-native", action="store_true")
    args = parser.parse_args()
    if args.command == "sdk":
        sdk(args)
    else:
        dependencies(args)


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        message = str(error).replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")
        print("::error title=MDF4 bootstrap failed::"+message, file=sys.stderr)
        raise
