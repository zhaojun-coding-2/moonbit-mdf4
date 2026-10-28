"""Independent native-record window acceptance using a real public API receiver.

python check_window.py example EXAMPLE_JSON
python check_window.py files RECEIVER_JS NEW_CAPTURE_DIRECTORY
Only standard Python/Node; no product decoder is imported or used as the oracle.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import struct
import subprocess

ROOT = Path(__file__).resolve().parents[1]
ORIGIN = "1793120324061712896"
MAX_ORIGIN = "18446744073709551615"


def digest(data):
    return hashlib.sha256(data).hexdigest()


def bits(value):
    return str(struct.unpack("<Q", struct.pack("<d", value))[0])


def scalar(kind, value):
    if kind in ("number", "real"):
        return {"kind": kind, "text": "", "bits": bits(value), "bytes": []}
    if kind in ("data", "octets"):
        return {"kind": kind, "text": "", "bits": None, "bytes": list(value)}
    return {"kind": kind, "text": str(value), "bits": None, "bytes": []}


def series(name, unit, times, raw_kind, raw, value_kind, values, valid):
    return {
        "name": name, "unit": unit, "raw": [scalar(raw_kind, value) for value in raw],
        "time_bits": [bits(t) for t in times],
        "values": [scalar(value_kind, value) for value in values], "valid": valid,
    }


def response(stage, **fields):
    return {"stage": stage, "error": None, "invalid_range": None,
            "window": None, "series": None, "raw": None, **fields}


def expected_window(index, start, count, data, origin=ORIGIN):
    end = start + count  # Only the independent oracle receives prevalidated ranges.
    raw = data["raw"][start:end]
    physical = {key: data[key] for key in ["name", "unit"]}
    physical.update({key: data[key][start:end] for key in ["time_bits", "values", "valid"]})
    return response("window_ok", window={
        "channel_index": index, "start_record": start, "record_count": count,
        "start_ns": origin, "raw": raw, "series": physical,
    })


def verify_example(path):
    actual = json.loads(path.read_text(encoding="utf-8"))
    expected = {"channel_index": 3, "start_record": 1, "record_count": 1,
                "start_ns": MAX_ORIGIN, "name": "速度🚲", "unit": "m/s",
                "raw": ["-99"], "timestamps": [11.5], "values": ["倒车"], "valid": [True]}
    assert actual == expected, (actual, expected)
    print(json.dumps({"status": "pass", "example": "window", "records": 1,
                      "source_clock": "10+2*0.75=11.5", "origin": MAX_ORIGIN}))


def block(data, address):
    length, count = struct.unpack_from("<QQ", data, address + 8)
    links = list(struct.unpack_from("<" + "Q" * count, data, address + 24))
    return links, address + 24 + count * 8, length - 24 - count * 8


def core_layout(data):
    hd, _, _ = block(data, 64)
    dg, dgpos, _ = block(data, hd[0])
    cg, cgpos, _ = block(data, dg[1])
    channels = []
    address = cg[1]
    while address:
        links, pos, _ = block(data, address)
        channels.append((address, links, pos))
        address = links[0]
    _, data_pos, _ = block(data, dg[2])
    size, invalid = struct.unpack_from("<II", data, cgpos + 24)
    assert data[dgpos] == 0 and len(channels) == 9 and size == 30 and invalid == 1
    return channels, data_pos, size + invalid


def append_block(data, kind, links, payload):
    data.extend(b"\0" * (-len(data) % 8))
    address = len(data)
    data.extend(struct.pack("<4s4xQQ", kind, 24 + len(links) * 8 + len(payload), len(links)))
    data.extend(struct.pack("<" + "Q" * len(links), *links))
    data.extend(payload)
    return address


def append_text(data, text):
    payload = text.encode("utf-8") + b"\0"
    payload += b"\0" * (-len(payload) % 8)
    return append_block(data, b"##TX", [], payload)


def append_conversion(data, kind, params=(), texts=()):
    refs = [append_text(data, text) for text in texts]
    payload = struct.pack("<BBHHHdd", kind, 0, 0, len(refs), len(params), 0.0, 0.0)
    payload += struct.pack("<" + "d" * len(params), *params)
    return append_block(data, b"##CC", [0, 0, 0, 0, *refs], payload)


def set_conversion(data, channel_address, conversion):
    struct.pack_into("<Q", data, channel_address + 24 + 4 * 8, conversion)


def file_acceptance(receiver, out):
    out.mkdir(parents=True, exist_ok=False)
    owned_paths = {
        "core": ROOT / "testdata/core-c0.mf4",
        "core-zlib": ROOT / "testdata/core-c1.mf4",
        "core-transpose": ROOT / "testdata/core-c2.mf4",
        "catalog": ROOT / "analysis/catalog_fixture/catalog.mf4",
        "unsupported": ROOT / "analysis/catalog_fixture/unsupported.mf4",
        "calibrated": ROOT / "analysis/summary_fixture/calibrated.mf4",
        "reversed": ROOT / "analysis/summary_fixture/reversed.mf4",
        "all-invalid": ROOT / "analysis/summary_fixture/all_invalid.mf4",
        "mixed": ROOT / "analysis/review_fixture/mixed.mf4",
        "empty": ROOT / "analysis/fixture/empty.mf4",
    }
    before = {name: digest(path.read_bytes()) for name, path in owned_paths.items()}
    assert before["core"] == "33821845b3577b23c709643dcd6fca0f27caa835c29cac44dad78b582aa8539c"
    assert before["catalog"] == "2ce2e2a4492429d8ddc77947a72733102c2469dd4293a28fabd885c541605e0d"
    core = owned_paths["core"].read_bytes()
    channels, dt, stride = core_layout(core)
    identity_address, _, identity_pos = channels[1]
    master_address, _, master_pos = channels[0]
    identity_offset = struct.unpack_from("<I", core, identity_pos + 4)[0]
    unsigned_offset = struct.unpack_from("<I", core, channels[8][2] + 4)[0]
    assert identity_offset == 8
    times = [struct.unpack_from("<d", core, dt + i * stride)[0] for i in range(6)]
    raw = [struct.unpack_from("<H", core, dt + i * stride + identity_offset)[0] for i in range(6)]
    masks = [core[dt + i * stride + 30] == 0 for i in range(6)]
    assert times == [0, .1, .2, .3, .4, .5] and raw == [0, 1, 2, 3, 4, 5]
    assert masks == [True, True, False, True, True, True]
    unsigned = [struct.unpack_from("<Q", core, dt + i * stride + unsigned_offset)[0] for i in range(6)]
    assert unsigned == [0, 1, 2**53 + 1, 2**63, 2**64 - 2, 2**64 - 1]
    normal = series("identity", "u", times, "unsigned", raw, "number", list(map(float, raw)), masks)
    u64 = series("uint64", "", times, "unsigned", unsigned, "number", list(map(float, unsigned)), [True] * 6)
    catalog_bytes = owned_paths["catalog"].read_bytes()
    payload = catalog_bytes[1232:1280]
    assert payload.hex() == "070000000000000000fdff0009000000000000d03f2a000007000000000000f03f06000109000000000000e83f9dff00"
    records = list(struct.iter_unpack("<BdhB", payload))
    assert records == [(7, 0.0, -3, 0), (9, .25, 42, 0), (7, 1.0, 6, 1), (9, .75, -99, 0)]
    kmh = series("速度🚲", "km/h", [0, 1], "signed", [-3, 6], "number", [-3.0, 6.0], [True, False])
    ms = series("速度🚲", "m/s", [.25, .75], "signed", [42, -99], "number", [42.0, -99.0], [True, True])
    calibrated = series("速度🚲", "m/s", [10 + 2 * .25, 10 + 2 * .75], "signed",
                        [42, -99], "label", ["前进", "倒车"], [True, True])
    cases, generated = [], {}

    def save(name, data):
        path = out / (name + ".mf4")
        path.write_bytes(data)
        generated[name] = {"path": str(path), "sha256": digest(data), "bytes": len(data)}
        return path

    def invoke(name, path, index, start, count, expected=None, *, mode="window",
               error=None, error_stage="window_source_error", limits=None):
        argv = ["node", str(receiver), mode, str(path), str(index), str(start), str(count)]
        if limits is not None:
            argv += list(map(str, limits))
        cp = subprocess.run(argv, capture_output=True)
        (out / (name + ".stdout")).write_bytes(cp.stdout)
        (out / (name + ".stderr")).write_bytes(cp.stderr)
        assert cp.returncode == 0 and cp.stderr == b"", (name, cp.returncode, cp.stderr)
        actual = json.loads(cp.stdout)
        if error is not None:
            if isinstance(error, str):
                expected = response(error_stage, error=error)
                assert actual == expected, (name, actual, expected)
            else:
                assert actual["stage"] == error_stage and actual["error"].startswith(error[0]), (name, actual)
                assert {key: value for key, value in actual.items() if key != "error"} == {
                    key: value for key, value in response(error_stage).items() if key != "error"
                }, (name, actual)
        else:
            assert actual == expected, (name, actual, expected)
        cases.append({"name": name, "argv": argv, "exit": cp.returncode, "stage": actual["stage"],
                      "expected": expected if error is None or isinstance(error, str) else {
                          "stage": error_stage, "sourceErrorCategory": error[0], "noPartialResult": True}})
        return actual

    for name, start, count in [
        ("first", 0, 1), ("middle", 2, 2), ("tail", 5, 1), ("full", 0, 6),
        ("empty-start", 0, 0), ("empty-middle", 3, 0), ("empty-end", 6, 0),
    ]:
        invoke(name, owned_paths["core"], 1, start, count, expected_window(1, start, count, normal))
    for name in ["core-zlib", "core-transpose"]:
        invoke(name + "-window", owned_paths[name], 1, 2, 2, expected_window(1, 2, 2, normal))
    master_ref = series("time", "s", times, "real", times, "number", times, [True] * 6)
    invoke("master-is-selected", owned_paths["core"], 0, 1, 3, expected_window(0, 1, 3, master_ref))
    invoke("zero-record-group", owned_paths["empty"], 1, 0, 0, expected_window(1, 0, 0, normal))
    invoke("zero-record-beyond-end", owned_paths["empty"], 1, 1, 0,
           response("range_error", invalid_range=[1, 0, 0]))
    invoke("zero-record-nonempty", owned_paths["empty"], 1, 0, 1,
           response("range_error", invalid_range=[0, 1, 0]))
    invoke("exact-uint64", owned_paths["core"], 8, 2, 4, expected_window(8, 2, 4, u64))
    for name, index, data in [("native-kmh", 1, kmh), ("native-ms", 3, ms)]:
        invoke(name, owned_paths["catalog"], index, 1, 1, expected_window(index, 1, 1, data, MAX_ORIGIN))
    invoke("calibrated-full", owned_paths["calibrated"], 3, 0, 2, expected_window(3, 0, 2, calibrated, MAX_ORIGIN))
    invoke("source-reversed", owned_paths["reversed"], 3, 0, 2,
           expected_window(3, 0, 2, {**calibrated, "time_bits": [bits(11.5), bits(10.5)]}, MAX_ORIGIN))
    invoke("all-invalid-retained", owned_paths["all-invalid"], 3, 0, 2,
           expected_window(3, 0, 2, {**calibrated, "valid": [False, False]}, MAX_ORIGIN))
    repeated = bytearray(owned_paths["calibrated"].read_bytes())
    struct.pack_into("<d", repeated, 1232 + 36 + 1, .25)
    repeated_path = save("repeated-native-clock", repeated)
    invoke("source-repeated", repeated_path, 3, 0, 2,
           expected_window(3, 0, 2, {**calibrated, "time_bits": [bits(10.5), bits(10.5)]}, MAX_ORIGIN))
    mixed = owned_paths["mixed"].read_bytes()
    assert digest(mixed) == "7bcd63e7f1aa923c5c1f2f97eebed1e767580efa8bdbcac365c4e35bf7072020"
    label = series("state", "u", [0, 1], "real", [1.0, 2.0], "label", ["1", "2"], [True, True])
    data = series("blob", "u", [0, 1], "octets", [struct.pack("<d", 1.0), struct.pack("<d", 2.0)],
                  "data", [struct.pack("<d", 1.0), struct.pack("<d", 2.0)], [True, True])
    invoke("label-kind", owned_paths["mixed"], 2, 0, 2, expected_window(2, 0, 2, label, MAX_ORIGIN))
    invoke("data-kind", owned_paths["mixed"], 3, 0, 2, expected_window(3, 0, 2, data, MAX_ORIGIN))

    # A sample-level formula domain error at the already-invalid record 2.
    # Narrow windows can deliver both sides; whole physical reads still fail.
    domain = bytearray(core)
    cc = append_conversion(domain, 3, texts=["1/(X-2)"])
    set_conversion(domain, identity_address, cc)
    domain_path = save("domain-outside", domain)
    domain_ref = {**normal, "values": [scalar("number", -.5), scalar("number", -1.0),
                                     None, scalar("number", 1.0), scalar("number", .5), None]}
    invoke("domain-before-bad", domain_path, 1, 0, 2, expected_window(1, 0, 2, domain_ref))
    invoke("domain-after-bad", domain_path, 1, 3, 2, expected_window(1, 3, 2, domain_ref))
    invoke("domain-empty-at-bad", domain_path, 1, 2, 0, expected_window(1, 2, 0, domain_ref))
    for name, start, count in [("domain-expand", 0, 3), ("domain-bad-only", 2, 1)]:
        invoke(name, domain_path, 1, start, count, error=("InvalidFormula(",))
    invoke("domain-old-whole", domain_path, 1, 0, 0, mode="whole",
           error=("InvalidFormula(",), error_stage="whole_error")
    invoke("domain-old-raw", domain_path, 1, 0, 0, mode="raw", expected=response("raw_ok", raw=normal["raw"]))

    # Invalid UTF-8 is confined to record 2. The direct old read_raw also fails,
    # so successful paired windows cannot be implemented as a full read + slice.
    text = bytearray(core)
    text[identity_pos + 2] = 7
    struct.pack_into("<I", text, identity_pos + 8, 32)
    set_conversion(text, identity_address, 0)
    words = ["A", "é", "bad", "D", "E", "F"]
    for i, word in enumerate(words):
        encoded = word.encode("utf-8") + b"\0"
        text[dt + i * stride + 8:dt + i * stride + 12] = encoded.ljust(4, b"Z")
    text[dt + 2 * stride + 8:dt + 2 * stride + 12] = b"\xc0\xaf\0Z"
    text_path = save("utf8-outside", text)
    text_ref = series("identity", "u", times, "text", words, "label", words, masks)
    invoke("utf8-before-bad", text_path, 1, 0, 2, expected_window(1, 0, 2, text_ref))
    invoke("utf8-after-bad", text_path, 1, 3, 2, expected_window(1, 3, 2, text_ref))
    invoke("utf8-empty-at-bad", text_path, 1, 2, 0, expected_window(1, 2, 0, text_ref))
    invoke("utf8-expand", text_path, 1, 0, 3, error='CorruptedBlock("invalid UTF-8 sample")')
    for mode in ["whole", "raw"]:
        invoke("utf8-old-" + mode, text_path, 1, 0, 0, mode=mode,
               error='CorruptedBlock("invalid UTF-8 sample")', error_stage=mode + "_error")

    invalid_master = bytearray(core)
    struct.pack_into("<II", invalid_master, master_pos + 12, 2, 0)
    master_path = save("invalid-master-outside", invalid_master)
    invoke("master-before-bad", master_path, 1, 0, 2, expected_window(1, 0, 2, normal))
    invoke("master-after-bad", master_path, 1, 3, 2, expected_window(1, 3, 2, normal))
    invoke("master-empty-at-bad", master_path, 1, 2, 0, expected_window(1, 2, 0, normal))
    invoke("master-expand", master_path, 1, 0, 3, error='InvalidTime("invalid master sample")')
    invoke("master-old-whole", master_path, 1, 0, 0, mode="whole",
           error='InvalidTime("invalid master sample")', error_stage="whole_error")
    both = bytearray(text)
    struct.pack_into("<II", both, master_pos + 12, 2, 0)
    both_path = save("master-and-utf8-bad", both)
    invoke("master-before-selected-decode", both_path, 1, 2, 1,
           error='InvalidTime("invalid master sample")')

    # Identity nonfinite values, raw negative zero and native non-monotonic
    # clocks remain existing semantics. Bits, not decimal text, are the oracle.
    real = bytearray(core)
    real[identity_pos + 2] = 4
    struct.pack_into("<I", real, identity_pos + 8, 64)
    set_conversion(real, identity_address, 0)
    real_values = [0.0, -0.0, math.nan, math.inf, -math.inf, 1.0]
    real_clocks = [0.0, .5, .25, .25, -1.0, 2.0]
    for i, (clock, value) in enumerate(zip(real_clocks, real_values)):
        struct.pack_into("<d", real, dt + i * stride, clock)
        struct.pack_into("<d", real, dt + i * stride + 8, value)
    real_path = save("native-real-bits", real)
    real_ref = series("identity", "u", real_clocks, "real", real_values, "number", real_values, masks)
    invoke("native-real-full", real_path, 1, 0, 6, expected_window(1, 0, 6, real_ref))

    for start, count in [(-1, 0), (0, -1), (7, 0), (6, 1), (1, 2147483647),
                         (2147483647, 2147483647), (-2147483648, 0)]:
        invoke("range-" + str(len(cases)), owned_paths["core"], 1, start, count,
               response("range_error", invalid_range=[start, count, 6]))
    invoke("channel-before-range", owned_paths["core"], -1, -1, 2147483647,
           error='ChannelNotFound("-1")')
    invoke("channel-upper-before-range", owned_paths["core"], 99, -1, -1,
           error='ChannelNotFound("99")')
    invoke("empty-selected-metadata", owned_paths["unsupported"], 1, 0, 0,
           error="UnsupportedConversion(99)")
    invoke("range-before-selected-metadata", owned_paths["unsupported"], 1, 3, 0,
           response("range_error", invalid_range=[3, 0, 2]))

    bad_master_meta = bytearray(core)
    meta99 = append_conversion(bad_master_meta, 99)
    set_conversion(bad_master_meta, master_address, meta99)
    bad_master_meta_path = save("master-unsupported-metadata", bad_master_meta)
    invoke("empty-master-metadata", bad_master_meta_path, 1, 0, 0, error="UnsupportedConversion(99)")
    both_meta = bytearray(core)
    meta98 = append_conversion(both_meta, 98)
    meta99 = append_conversion(both_meta, 99)
    set_conversion(both_meta, master_address, meta98)
    set_conversion(both_meta, identity_address, meta99)
    both_meta_path = save("both-unsupported-metadata", both_meta)
    invoke("selected-before-master-metadata", both_meta_path, 1, 0, 0, error="UnsupportedConversion(99)")
    missing = bytearray(both_meta)
    missing[master_pos] = 0
    missing_path = save("missing-master", missing)
    invoke("empty-missing-master", missing_path, 1, 0, 0, error='InvalidTime("no time master")')
    multiple = bytearray(both_meta)
    multiple[channels[2][2]] = 2
    multiple[channels[2][2] + 1] = 1
    multiple_path = save("multiple-masters", multiple)
    invoke("empty-multiple-masters", multiple_path, 1, 0, 0, error='InvalidTime("multiple time masters")')
    bad_params = bytearray(core)
    bad_cc = append_conversion(bad_params, 1, params=[2.0])
    set_conversion(bad_params, identity_address, bad_cc)
    bad_params_path = save("bad-selected-parameters", bad_params)
    invoke("empty-bad-selected-parameters", bad_params_path, 1, 0, 0,
           error='CorruptedBlock("linear CC requires two parameters")')

    corrupt = bytearray(catalog_bytes)
    corrupt[1232 + 36] = 99
    corrupt_path = save("late-unknown-record-id", corrupt)
    invoke("open-late-structure-error", corrupt_path, 1, 0, 1,
           error='CorruptedBlock("unknown record ID or missing group")', error_stage="open_error")
    for name, path, limits in [
        ("samples", owned_paths["core"], [1, 67108864, 100000]),
        ("output", owned_paths["core-transpose"], [1000000, 100, 100000]),
        ("blocks", owned_paths["core"], [1000000, 67108864, 1]),
    ]:
        invoke("open-budget-" + name, path, 1, 0, 0, error=("LimitExceeded(",),
               error_stage="open_error", limits=limits)

    assert all(digest(path.read_bytes()) == before[name] for name, path in owned_paths.items())
    report = {
        "status": "pass", "cases": cases, "case_count": len(cases),
        "window_successes": sum(case["stage"] == "window_ok" for case in cases),
        "window_source_errors": sum(case["stage"] == "window_source_error" for case in cases),
        "range_errors": sum(case["stage"] == "range_error" for case in cases),
        "open_errors": sum(case["stage"] == "open_error" for case in cases),
        "whole_raw_control_calls": sum(case["argv"][2] != "window" for case in cases),
        "original_sources_unchanged": True, "original_source_hashes": before,
        "generated_owned_inputs": generated, "original_mixed_record_hex": payload.hex(),
        "independent_uint64_values": list(map(str, unsigned)),
        "compiled_receiver_sha256": digest(receiver.read_bytes()),
        "reference": "Original owned bytes plus Python struct, literal values and simple exact arithmetic; no product decoder or full read is the oracle",
    }
    (out / "verification.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({key: report[key] for key in ["status", "case_count", "window_successes", "window_source_errors",
                                                  "range_errors", "open_errors", "whole_raw_control_calls",
                                                  "compiled_receiver_sha256"]}))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    commands = parser.add_subparsers(dest="mode", required=True)
    example = commands.add_parser("example")
    example.add_argument("json", type=Path)
    files = commands.add_parser("files")
    files.add_argument("receiver", type=Path)
    files.add_argument("out", type=Path)
    args = parser.parse_args()
    if args.mode == "example":
        verify_example(args.json)
    else:
        file_acceptance(args.receiver.resolve(), args.out.resolve())
