"""Verify four saved native-window handoff files using Python stdlib only.

This verifies content bindings and protocol consistency, not arbitrary MDF
decoding, a signature, an atomic acquisition, or the truth of claimed samples.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import sys


def require(condition, message):
    if not condition:
        raise ValueError(message)


def exact(value, fields, label):
    require(type(value) is dict and set(value) == set(fields), label + ": invalid fields")


def decimal(value, maximum=None, signed=False):
    pattern = r"(?:0|[1-9][0-9]*|-[1-9][0-9]*)" if signed else r"(?:0|[1-9][0-9]*)"
    require(type(value) is str and re.fullmatch(pattern, value) is not None, "invalid decimal string")
    # The protocol's relevant integer bounds are small; reject enormous spellings
    # before int(), independently of Python's configurable integer digit limit.
    if maximum is not None:
        require(len(value.lstrip("-")) <= len(str(maximum)), "integer out of range")
    n = int(value)
    if maximum is not None:
        require(n <= maximum and (not signed or n >= -(2**63)), "integer out of range")
    return n


def text(value):
    require(type(value) is str and not any(0xD800 <= ord(c) <= 0xDFFF for c in value), "invalid Unicode text")


def hex_string(value, width=None):
    require(type(value) is str and re.fullmatch(r"[0-9a-f]*", value) is not None and len(value) % 2 == 0,
            "invalid lowercase hex")
    if width is not None:
        require(len(value) == width, "invalid bit width")


def scalar(value, raw):
    require(type(value) is dict, "missing typed scalar")
    kind = value.get("kind")
    allowed = {"unsigned":"decimal", "signed":"decimal", "real":"bits", "text":"text", "octets":"hex"} if raw else {"number":"bits", "label":"text", "data":"hex"}
    require(type(kind) is str and kind in allowed, "invalid scalar kind")
    field = allowed[kind]
    exact(value, ["kind", field], "scalar")
    payload = value[field]
    if field == "decimal":
        decimal(payload, 2**64-1 if kind == "unsigned" else 2**63-1, kind == "signed")
    elif field == "bits":
        hex_string(payload, 16)
    elif field == "hex":
        hex_string(payload)
    else:
        text(payload)


def fingerprint(raw):
    return {"bytes": str(len(raw)), "sha256": hashlib.sha256(raw).hexdigest()}


def binding(value, raw, encoding=False):
    exact(value, ["bytes", "sha256", *(["encoding"] if encoding else [])], "fingerprint")
    # Exact equality also rejects numeric/bool coercion and malformed digests.
    require(value == {**fingerprint(raw), **({"encoding":"UTF-8"} if encoding else {})}, "saved byte fingerprint mismatch")


def parse(raw):
    def invalid_constant(value):
        raise ValueError("invalid JSON constant: " + value)
    # json.loads and JSON.parse both use the last effective duplicate member.
    return json.loads(raw.decode("utf-8-sig"), parse_constant=invalid_constant)


def verify(source_bytes, request_bytes, result_bytes, receipt_bytes):
    request, result, receipt = map(parse, [request_bytes, result_bytes, receipt_bytes])
    exact(request, ["request_version", "source", "windows"], "request")
    require(request["request_version"] == "mdf4.native-window.request/1", "request version")
    binding(request["source"], source_bytes)
    exact(receipt, ["receipt_version", "source", "request", "result", "result_version", "window_count", "returned_record_count"], "receipt")
    require(receipt["receipt_version"] == "mdf4.native-window.receipt/1", "receipt version")
    binding(receipt["source"], source_bytes)
    binding(receipt["request"], request_bytes)
    binding(receipt["result"], result_bytes, True)
    require(receipt["result_version"] == "mdf4.native-window.result/1", "receipt result version")
    exact(result, ["result_version", "file", "windows"], "result")
    require(result["result_version"] == "mdf4.native-window.result/1", "result version")
    exact(result["file"], ["version", "start_ns"], "file")
    require(result["file"]["version"] in ("4.10", "4.11"), "file version")
    decimal(result["file"]["start_ns"], 2**64-1)
    selections, windows = request["windows"], result["windows"]
    require(type(selections) is list and len(selections) <= 4096, "request windows")
    require(type(windows) is list and len(windows) == len(selections), "window cardinality")
    metadata, masters, records, clocks = {}, {}, {}, {}
    total, invalid = 0, 0
    for ordinal, (selection, window) in enumerate(zip(selections, windows)):
        exact(selection, ["channel_index", "expected_group", "start_record", "record_count"], "selection")
        for value in selection.values():
            decimal(value, 2**31-1)
        exact(window, ["ordinal", "channel_index", "group_index", "master_channel_index", "name", "unit", "master_unit",
                       "start_record", "record_count", "time_unit", "time_bits", "raw", "values", "valid"], "window")
        require(window["ordinal"] == str(ordinal), "window ordinal")
        for output, input_key in [("channel_index","channel_index"), ("group_index","expected_group"), ("start_record","start_record"), ("record_count","record_count")]:
            require(window[output] == selection[input_key], "ordered selection mismatch")
        decimal(window["master_channel_index"], 2**31-1)
        for name in ["name", "unit", "master_unit"]:
            text(window[name])
        require(window["time_unit"] == "native_master_physical", "time unit")
        count = decimal(window["record_count"], 2**31-1)
        total += count
        require(total <= 1000000, "handoff returned-record limit")
        for name in ["time_bits", "raw", "values", "valid"]:
            require(type(window[name]) is list and len(window[name]) == count, "parallel array length")
        index, group, master = window["channel_index"], window["group_index"], window["master_channel_index"]
        info = tuple(window[k] for k in ["group_index", "master_channel_index", "name", "unit", "master_unit"])
        require(index not in metadata or metadata[index] == info, "channel metadata disagreement")
        metadata[index] = info
        m = (master, window["master_unit"])
        require(group not in masters or masters[group] == m, "group master disagreement")
        masters[group] = m
        for offset in range(count):
            t, raw, value, valid = (window[k][offset] for k in ["time_bits", "raw", "values", "valid"])
            hex_string(t, 16)
            require(int(t, 16) & 0x7ff0000000000000 != 0x7ff0000000000000, "nonfinite native clock")
            scalar(raw, True)
            scalar(value, False)
            require(type(valid) is bool, "validity must be Boolean")
            if index == master:
                require(value == {"kind":"number", "bits":t} and valid, "selected master/time disagreement")
            key = (index, int(window["start_record"]) + offset)
            sample = (t, raw, value, valid)
            require(key not in records or records[key] == sample, "repeated record disagreement")
            records[key] = sample
            clock_key = (group, key[1])
            require(clock_key not in clocks or clocks[clock_key] == t, "group record clock disagreement")
            clocks[clock_key] = t
            invalid += not valid
    for group, (master, unit) in masters.items():
        if master in metadata:
            require(metadata[master][0] == group and metadata[master][1] == master and metadata[master][3] == unit,
                    "master metadata disagreement")
    require(receipt["window_count"] == str(len(windows)) and receipt["returned_record_count"] == str(total), "receipt counts")
    return {"status":"pass", "windows":len(windows), "returned_records":total, "invalid_records":invalid,
            "source":fingerprint(source_bytes), "request":fingerprint(request_bytes), "result":fingerprint(result_bytes)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ["source", "request", "result", "receipt"]:
        parser.add_argument(name, type=Path)
    args = parser.parse_args()
    verified = verify(*(getattr(args, name).read_bytes() for name in ["source", "request", "result", "receipt"]))
    print(json.dumps(verified, ensure_ascii=False))


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, UnicodeError, TypeError) as error:
        print("native handoff rejected: " + str(error), file=sys.stderr)
        raise SystemExit(1)
