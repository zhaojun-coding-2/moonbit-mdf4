"""Exercise saved-file CRLF consistency with frozen, complete receiver inputs.

Usage: python validation/check_record_newlines.py NEW_CAPTURE_DIRECTORY
The literal cases predate the fix. No MDF producer or decoder builds the oracle.
"""
from pathlib import Path
import base64
import csv
import hashlib
import io
import json
import os
import subprocess
import sys

from verify_export import verify

ROOT = Path(__file__).resolve().parents[1]


def sha(data):
    return hashlib.sha256(data).hexdigest()


def main():
    if len(sys.argv) != 2:
        raise ValueError("Usage: check_record_newlines.py NEW_CAPTURE_DIRECTORY")
    out = Path(sys.argv[1]).resolve()
    out.mkdir(parents=True, exist_ok=False)
    fixture = ROOT / "validation/record-newlines-cases.json"
    frozen = fixture.read_bytes()
    cases = json.loads(frozen)
    assert cases["version"] == "mdf4.record-newlines.cases/1"
    source_path = ROOT / cases["source_path"]
    source = source_path.read_bytes()
    assert sha(source) == cases["source_sha256"] and len(source) == cases["source_bytes"]
    saved_source = out / "source.mf4"
    saved_source.write_bytes(source)
    verifier = ROOT / "validation/verify_export.py"
    receiver = Path(__file__).resolve()
    before = {str(p): sha(p.read_bytes()) for p in [source_path, fixture, verifier, receiver]}
    results = []
    original_limit = csv.field_size_limit()
    try:
        for case in cases["cases"]:
            name = case["name"]
            data = base64.b64decode(case["csv_base64"], validate=True)
            assert sha(data) == case["csv_sha256"] and len(data) == case["csv_bytes"]
            receipt_bytes = (json.dumps(case["receipt"], ensure_ascii=False, indent=2) + "\n").encode()
            assert sha(receipt_bytes) == case["receipt_sha256"]
            csv_path, receipt_path = out / (name + ".csv"), out / (name + ".receipt.json")
            csv_path.write_bytes(data)
            receipt_path.write_bytes(receipt_bytes)
            receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
            # Standard CSV parsing must preserve every literal field, including
            # legal quoted LF/CR/CRLF, doubled quotes and an unquoted A"B.
            if case["expected_rows"] is not None:
                rows = list(csv.reader(io.StringIO(data.decode("utf-8"), newline=""), strict=True))
                assert rows == case["expected_rows"], name
            expected = {
                "status": "pass", "rows": receipt["table"]["row_count"],
                "columns": len(receipt["table"]["columns"]),
                "source_sha256": cases["source_sha256"], "csv_sha256": case["csv_sha256"],
            }
            imported = []
            # Check the caller's normal setting and a deliberately small one.
            # Each call must restore the exact setting on success and error.
            for limit in [original_limit, 17]:
                csv.field_size_limit(limit)
                try:
                    value = verify(source, data, receipt)
                except (ValueError, csv.Error) as error:
                    assert case["expected_exit"] == 1 and str(error) == case["expected_error"], (name, error)
                    imported.append({"field_limit": limit, "exit": 1, "error": str(error), "type": type(error).__name__})
                else:
                    assert case["expected_exit"] == 0 and value == expected, (name, value)
                    imported.append({"field_limit": limit, "exit": 0, "result": value})
                assert csv.field_size_limit() == limit, name
            csv.field_size_limit(original_limit)
            argv = [sys.executable, "-B", str(verifier), str(saved_source), str(csv_path), str(receipt_path)]
            cp = subprocess.run(argv, cwd=ROOT, capture_output=True)
            (out / (name + ".stdout")).write_bytes(cp.stdout)
            (out / (name + ".stderr")).write_bytes(cp.stderr)
            result = {
                "name": name, "argv": argv, "cwd": str(ROOT), "exit": cp.returncode,
                "expected_exit": case["expected_exit"], "expected_error": case["expected_error"],
                "stdout": name + ".stdout", "stdout_sha256": sha(cp.stdout),
                "stderr": name + ".stderr", "stderr_sha256": sha(cp.stderr), "imported": imported,
                "csv_sha256": sha(csv_path.read_bytes()), "receipt_sha256": sha(receipt_path.read_bytes()),
            }
            results.append(result)
            (out / "cases.json").write_text(json.dumps(results, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
            assert cp.returncode == case["expected_exit"], (name, cp.returncode, cp.stdout, cp.stderr)
            if case["expected_exit"] == 0:
                assert cp.stderr == b"" and json.loads(cp.stdout) == expected, (name, cp.stdout, cp.stderr)
            else:
                error = ("Export verification failed: " + case["expected_error"] + os.linesep).encode()
                assert cp.stdout == b"" and cp.stderr == error, (name, cp.stdout, cp.stderr)
            assert csv_path.read_bytes() == data and receipt_path.read_bytes() == receipt_bytes
        assert {str(p): sha(p.read_bytes()) for p in [source_path, fixture, verifier, receiver]} == before
        assert saved_source.read_bytes() == source
    finally:
        csv.field_size_limit(original_limit)
    manifest = {
        "status": "pass", "case_count": len(results), "accepted": 2, "rejected": 6,
        "new_record_separator_rejections": 3, "existing_error_controls": 3,
        "imported_calls": len(results) * 2, "field_limit_restored": True,
        "inputs_and_receiver_unchanged": True, "fixture_sha256": sha(frozen),
        "source_sha256": sha(source), "verifier_sha256": before[str(verifier)],
        "receiver_sha256": before[str(receiver)], "cases": results,
        "evidence_boundary": "Own independent receiver. Hand-written contract controls do not reparse MDF or prove external adoption; canonical output is retained from accepted R05 without regeneration.",
    }
    (out / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({k: manifest[k] for k in ["status", "case_count", "accepted", "rejected", "new_record_separator_rejections", "imported_calls", "field_limit_restored", "fixture_sha256", "verifier_sha256", "receiver_sha256"]}))


if __name__ == "__main__":
    main()
