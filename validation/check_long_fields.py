"""Actual exporter -> saved receipt regression for long legal CSV text.

Usage: python validation/check_long_fields.py COMPILED_EXPORT_JS NEW_CAPTURE_DIR
Uses only self-created fixture derivatives and Python's standard library.
"""
from pathlib import Path
import copy
import csv
import hashlib
import io
import json
import os
import shutil
import struct
import subprocess
import sys

from verify_export import verify

PROJECT = Path(__file__).resolve().parents[1]
BOUNDARY = 131072
ORIGIN = "18446744073709551615"


def digest(data):
    return hashlib.sha256(data).hexdigest()


def make_source(label):
    """Append an owned TX and redirect the first CC7 enum; leave samples intact."""
    b = bytearray((PROJECT/"analysis/fixture/labels.mf4").read_bytes())
    assert digest(b) == "606a23bcf7416fd7204b4cc4c80ef91f71a174ebd2cb88904d4a72a48c74148d"

    def links(address):
        count = struct.unpack_from("<Q", b, address+16)[0]
        return list(struct.unpack_from("<"+"Q"*count, b, address+24))

    def text(address):
        count = struct.unpack_from("<Q", b, address+16)[0]
        length = struct.unpack_from("<Q", b, address+8)[0]
        return b[address+24+count*8:address+length].split(b"\0")[0].decode("utf-8")

    hd = links(64)
    dg = links(hd[0])
    group = dg[1]
    conversion = None
    while group:
        group_links = links(group)
        channel = group_links[1]
        while channel:
            channel_links = links(channel)
            if text(channel_links[2]) == "g1":
                conversion = channel_links[4]
            channel = channel_links[0]
        group = group_links[0]
    assert conversion and b[conversion:conversion+4] == b"##CC"
    b.extend(b"\0"*(-len(b)%8))
    address = len(b)
    payload = label.encode("utf-8")+b"\0"
    payload += b"\0"*(-len(payload)%8)
    b.extend(struct.pack("<4s4xQQ", b"##TX", 24+len(payload), 0)+payload)
    struct.pack_into("<Q", b, conversion+24+4*8, address)
    return bytes(b)


def expected_csv(label):
    target = io.StringIO(newline="")
    writer = csv.writer(target, quoting=csv.QUOTE_ALL, lineterminator="\r\n")
    writer.writerows([["start_ns", "time_s", "state", "state__valid"],
        [ORIGIN, "0.25", label, "true"], [ORIGIN, "0.75", "", "true"]])
    return target.getvalue().encode("utf-8")


def main():
    if len(sys.argv) != 3:
        raise ValueError("Usage: check_long_fields.py COMPILED_EXPORT_JS NEW_CAPTURE_DIR")
    executable = Path(sys.argv[1]).resolve()
    output = Path(sys.argv[2]).resolve()
    output.mkdir(parents=True, exist_ok=False)
    node = shutil.which("node")
    assert node
    env = os.environ.copy()
    env["PYTHONDONTWRITEBYTECODE"] = "1"
    env["PYTHONIOENCODING"] = "utf-8"
    original_limit = csv.field_size_limit()
    phrase = '状态🚦,"就绪"\n'
    cases = [("at-boundary", "A"*BOUNDARY, original_limit),
             ("above-boundary", "A"*(BOUNDARY+1), original_limit),
             ("unicode-multiline", (phrase*(BOUNDARY//len(phrase)+1))[:BOUNDARY+1], 32)]
    commands = []
    results = []

    def command(name, argv):
        p = subprocess.run(argv, capture_output=True, env=env)
        (output/(name+".stdout")).write_bytes(p.stdout)
        (output/(name+".stderr")).write_bytes(p.stderr)
        commands.append({"name": name, "argv": argv, "exit": p.returncode})
        (output/"commands.json").write_text(json.dumps(commands, indent=2)+"\n", encoding="utf-8")
        return p

    for name, label, caller_limit in cases:
        source = output/(name+".mf4")
        source.write_bytes(make_source(label))
        csv_path = output/(name+".csv")
        receipt_path = output/(name+".receipt.json")
        export = command(name+"-export", [node, str(executable), str(source), "0.25,0.75", "state", "3", "previous", "--receipt", str(receipt_path)])
        assert export.returncode == 0, export.stderr
        csv_path.write_bytes(export.stdout)
        assert export.stdout == expected_csv(label), name
        receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
        assert receipt["table"]["columns"][0]["valid_value_kinds"] == ["label"]
        assert receipt["table"]["columns"][0]["valid_rows"] == 2
        assert receipt["table"]["columns"][0]["invalid_rows"] == 0
        assert receipt["table"]["max_gap_seconds"] is None
        assert receipt["table"]["start_ns"] == ORIGIN
        csv.field_size_limit(caller_limit)
        try:
            checked = verify(source.read_bytes(), csv_path.read_bytes(), receipt)
            assert csv.field_size_limit() == caller_limit
        finally:
            csv.field_size_limit(original_limit)
        assert checked["status"] == "pass" and checked["rows"] == 2 and checked["columns"] == 1
        results.append({"name": name, "label_characters": len(label), "label_utf8_bytes": len(label.encode("utf-8")),
            "source_sha256": digest(source.read_bytes()), "csv_sha256": digest(export.stdout),
            "csv_bytes": len(export.stdout), "caller_field_limit": caller_limit, "limit_restored": True,
            "rows": checked["rows"], "complete_csv_bytes_equal_independent_writer": True})

    # Exercise the actual saved-byte verifier CLI once on the over-boundary case.
    name = "above-boundary"
    cli = command("long-field-cli", [sys.executable, str(PROJECT/"validation/verify_export.py"), str(output/(name+".mf4")), str(output/(name+".csv")), str(output/(name+".receipt.json"))])
    assert cli.returncode == 0, cli.stderr
    cli_result = json.loads(cli.stdout)
    assert cli_result == {"status": "pass", "rows": 2, "columns": 1,
        "source_sha256": results[1]["source_sha256"], "csv_sha256": results[1]["csv_sha256"]}

    # Strict parsing must still reject an unterminated long quoted field, and
    # the newly adjusted parser limit must be restored on that exception path.
    label = cases[2][1]
    header = b'"start_ns","time_s","state","state__valid"\r\n'
    malformed = header+('"'+ORIGIN+'","0.25","'+label.replace('"', '""')+'\r\n').encode("utf-8")
    bad_csv = output/"unterminated.csv"
    bad_csv.write_bytes(malformed)
    bad_receipt = copy.deepcopy(json.loads((output/"unicode-multiline.receipt.json").read_text(encoding="utf-8")))
    bad_receipt["csv"]["bytes"] = len(malformed)
    bad_receipt["csv"]["sha256"] = digest(malformed)
    bad_receipt_path = output/"unterminated.receipt.json"
    bad_receipt_path.write_text(json.dumps(bad_receipt, indent=2)+"\n", encoding="utf-8")
    csv.field_size_limit(32)
    try:
        try:
            verify((output/"unicode-multiline.mf4").read_bytes(), malformed, bad_receipt)
        except csv.Error as error:
            parse_error = str(error)
            assert "unexpected end of data" in parse_error
        else:
            raise AssertionError("Unterminated quoted field was accepted")
        assert csv.field_size_limit() == 32
    finally:
        csv.field_size_limit(original_limit)
    rejected = command("unterminated-cli", [sys.executable, str(PROJECT/"validation/verify_export.py"), str(output/"unicode-multiline.mf4"), str(bad_csv), str(bad_receipt_path)])
    assert rejected.returncode == 1 and rejected.stdout == b""
    assert b"unexpected end of data" in rejected.stderr and b"Traceback" not in rejected.stderr
    assert csv.field_size_limit() == original_limit
    summary = {"status": "pass", "producer_exports": 3, "data_rows": 6, "valid_import_checks": 3,
        "valid_cli_checks": 1, "strict_error_import_checks": 1, "strict_error_cli_checks": 1,
        "original_field_limit": original_limit, "final_field_limit": csv.field_size_limit(),
        "exception": parse_error, "compiled_export_sha256": digest(executable.read_bytes()),
        "cases": results, "commands": commands,
        "reference": "Actual frozen MoonBit exporter; independent Python csv.writer complete-byte/literal expectations"}
    (output/"acceptance.json").write_text(json.dumps(summary, indent=2)+"\n", encoding="utf-8")
    print(json.dumps({k:summary[k] for k in ["status", "producer_exports", "data_rows", "valid_import_checks", "valid_cli_checks", "strict_error_import_checks", "strict_error_cli_checks", "original_field_limit", "final_field_limit"]}))


if __name__ == "__main__":
    main()
