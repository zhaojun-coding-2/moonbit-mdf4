"""Real catalogue -> indexed inspector consumer with independent byte/value oracles.

Usage: check_inspect.py CHANNELS_JS INSPECT_JS NEW_CAPTURE_DIRECTORY
Standard Python and Node only; creates owned derivatives without altering fixtures.
"""
from pathlib import Path
import hashlib
import json
import math
import struct
import subprocess
import sys

p = Path(__file__).resolve().parents[1]
channels_js, inspect_js, out = map(lambda value: Path(value).resolve(), sys.argv[1:])
out.mkdir(parents=True, exist_ok=False)
catalog = p / "analysis/catalog_fixture/catalog.mf4"
files = [
    catalog, p / "analysis/catalog_fixture/unsupported.mf4",
    p / "analysis/summary_fixture/calibrated.mf4", p / "analysis/summary_fixture/reversed.mf4",
    p / "testdata/core-c0.mf4", p / "testdata/core-c2.mf4",
    p / "analysis/fixture/nonfinite.mf4", p / "analysis/fixture/single.mf4",
]
before = {str(path): hashlib.sha256(path.read_bytes()).hexdigest() for path in files}
commands, indexed_cases = [], []


def invoke(name, executable, args):
    argv = ["node", str(executable), *map(str, args)]
    cp = subprocess.run(argv, capture_output=True)
    (out / (name + ".stdout")).write_bytes(cp.stdout)
    (out / (name + ".stderr")).write_bytes(cp.stderr)
    commands.append({"name": name, "argv": argv, "exit": cp.returncode})
    return cp


def invalid_json_number(token):
    raise AssertionError("Non-JSON numeric token: " + token)


def decode(data):
    return json.loads(data.decode("utf-8"), parse_constant=invalid_json_number)


def expected(name, unit, raw, times, valid, values):
    return {"name": name, "unit": unit, "raw": raw, "timestamps": times, "valid": valid, "values": values}


def inspect(name, file, index, reference):
    cp = invoke(name, inspect_js, [file, "--index", index])
    assert cp.returncode == 0 and cp.stderr == b"", (name, cp.stderr)
    # Physical numeric values and clocks have the documented Double semantics;
    # exact integer strings above 2**53 are checked separately against raw bytes.
    actual = json.loads(cp.stdout.decode("utf-8"), parse_int=float, parse_constant=invalid_json_number)
    assert actual == reference, (name, actual, reference)
    indexed_cases.append(name)
    return cp


# The fixture's fixed bytes contain four interleaved <record-id, f64, i16, mask>
# records. These literal original bytes and Python's aligned unpacking are
# independent of the product's MDF traversal and bit-field decoder.
b = catalog.read_bytes()
assert before[str(catalog)] == "2ce2e2a4492429d8ddc77947a72733102c2469dd4293a28fabd885c541605e0d"
assert b[1208:1212] == b"##DT"
payload = b[1232:1280]
assert payload.hex() == "070000000000000000fdff0009000000000000d03f2a000007000000000000f03f06000109000000000000e83f9dff00"
records = list(struct.iter_unpack("<BdhB", payload))
assert records == [(7, 0.0, -3, 0), (9, .25, 42, 0), (7, 1.0, 6, 1), (9, .75, -99, 0)]
kmh = expected("速度🚲", "km/h", ["-3", "6"], [0, 1], [True, False], [-3, 6])
ms = expected("速度🚲", "m/s", ["42", "-99"], [.25, .75], [True, True], [42, -99])
cat = invoke("catalogue", channels_js, [catalog])
assert cat.returncode == 0 and cat.stderr == b""
rows = decode(cat.stdout)["channels"]
chosen = []
for group, unit, reference, index in [(0, "km/h", kmh, 1), (1, "m/s", ms, 3)]:
    matches = [row for row in rows if row["name"] == "速度🚲" and row["group"] == group and row["unit"] == unit]
    assert len(matches) == 1 and matches[0]["index"] == index
    chosen.append(index)
    inspect("selected-" + str(index), catalog, matches[0]["index"], reference)
inspect("index-zero-master", catalog, 0, expected("time", "", ["0", "1"], [0, 1], [True, True], [0, 1]))
inspect("leading-zero", catalog, "03", ms)
inspect("explicit-plus", catalog, "+3", ms)

# Same record payload; CC1 maps the second master's .25/.75 to 10.5/11.5,
# and the owned CC7 maps 42/-99 to the literal labels below. Source order stays.
calibrated = p / "analysis/summary_fixture/calibrated.mf4"
assert calibrated.read_bytes()[1232:1280] == payload
state = expected("速度🚲", "m/s", ["42", "-99"], [10 + 2 * .25, 10 + 2 * .75], [True, True], ["前进", "倒车"])
inspect("calibrated-master", calibrated, 3, state)
inspect("source-order", p / "analysis/summary_fixture/reversed.mf4", 3, {**state, "timestamps": [11.5, 10.5]})
inspect("unrelated-unsupported", p / "analysis/catalog_fixture/unsupported.mf4", 3, ms)


def block(data, address):
    count = struct.unpack_from("<Q", data, address + 16)[0]
    return list(struct.unpack_from("<" + "Q" * count, data, address + 24)), address + 24 + count * 8


# Direct aligned UInt64 reads of the original uncompressed records establish
# exact strings above 2**53 independently of the physical Double representation.
core = (p / "testdata/core-c0.mf4").read_bytes()
hd, _ = block(core, 64)
dg, _ = block(core, hd[0])
cg, cgdata = block(core, dg[1])
channel = cg[1]
for _ in range(8):
    links, _ = block(core, channel)
    channel = links[0]
_, channeldata = block(core, channel)
offset = struct.unpack_from("<I", core, channeldata + 4)[0]
assert core[channeldata + 2] == 0 and core[channeldata + 3] == 0
assert struct.unpack_from("<I", core, channeldata + 8)[0] == 64
size, invalid = struct.unpack_from("<II", core, cgdata + 24)
_, data = block(core, dg[2])
unsigned = [struct.unpack_from("<Q", core, data + i * (size + invalid) + offset)[0] for i in range(6)]
assert unsigned == [0, 1, 2**53 + 1, 2**63, 2**64 - 2, 2**64 - 1]
inspect("exact-uint64", p / "testdata/core-c0.mf4", 8,
        expected("uint64", "", list(map(str, unsigned)), [0, .1, .2, .3, .4, .5], [True] * 6, list(map(float, unsigned))))
nonfinite = expected("identity", "u", ["NaN", "Infinity", "-Infinity", "1", "2", "3"],
                     [0, .1, .2, .3, .4, .5], [True, True, False, True, True, True],
                     ["NaN", "Infinity", "-Infinity", 1, 2, 3])
inspect("nonfinite", p / "analysis/fixture/nonfinite.mf4", 1, nonfinite)
# The original bytes contain a -0 master and the minimum positive subnormal
# signal. Keep the old inspector's numeric/raw-float spelling (0 for -0),
# rather than changing that serialization while adding index selection.
single_file = p / "analysis/fixture/single.mf4"
single_bytes = single_file.read_bytes()
assert before[str(single_file)] == "9d448a1bb77b7804ffc4b9e5f3c74f2451cfb508b69adc6da8cba0dec154b111"
assert struct.unpack_from("<Q", single_bytes, 3480)[0] == 1 << 63
assert struct.unpack_from("<Q", single_bytes, 3488)[0] == 1
minimum = struct.unpack("<d", bytes.fromhex("0100000000000000"))[0]
single = inspect("negative-zero", single_file, 1,
                 expected("identity", "u", ["5e-324"], [0], [True], [minimum]))
inspect("negative-zero-master", single_file, 0,
        expected("time", "s", ["0"], [0], [True], [0]))
clock = json.loads(single.stdout, parse_int=float)["timestamps"][0]
assert math.copysign(1.0, clock) == 1.0

# A real pre-existing literal --index channel remains selected by the old
# two-argument form. Only one appended TX and one name link change the fixture.
flag_data = bytearray(b)
hd, _ = block(flag_data, 64)
dg, _ = block(flag_data, hd[0])
cg, _ = block(flag_data, dg[1])
master, _ = block(flag_data, cg[1])
signal = master[0]
flag_data.extend(b"\0" * (-len(flag_data) % 8))
address = len(flag_data)
flag_data.extend(struct.pack("<4s4xQQ", b"##TX", 32, 0) + b"--index\0")
struct.pack_into("<Q", flag_data, signal + 24 + 2 * 8, address)
flag_file = out / "literal-flag-name.mf4"
flag_file.write_bytes(flag_data)
legacy_cases = [
    ("legacy-flag-name", flag_file, "--index", {**kmh, "name": "--index"}),
    ("legacy-finite", p / "testdata/core-c2.mf4", "linear",
     expected("linear", "u", ["0", "1", "2", "3", "4", "5"], [0, .1, .2, .3, .4, .5],
              [True, True, False, True, True, True], [-3, -.5, 2, 4.5, 7, 9.5])),
    ("legacy-nonfinite", p / "analysis/fixture/nonfinite.mf4", "identity", nonfinite),
]
for name, file, channel, reference in legacy_cases:
    cp = invoke(name, inspect_js, [file, channel])
    assert cp.returncode == 0 and cp.stderr == b"" and decode(cp.stdout) == reference
metadata = invoke("legacy-catalog-metadata", inspect_js, [catalog])
assert metadata.returncode == 0 and metadata.stderr == b""
assert decode(metadata.stdout) == {"version": "4.10", "start_ns": str(2**64 - 1), "channels": ["time", "速度🚲", "time", "速度🚲"]}
ambiguous = invoke("legacy-ambiguous", inspect_js, [catalog, "速度🚲"])
assert ambiguous.returncode == 1 and ambiguous.stderr == b"" and ambiguous.stdout.decode() == 'channel error: AmbiguousChannel("速度🚲")\n'

errors = []
for i, index in enumerate(["", "-1", "1.5", "true", "0x1", "2147483648", "99"]):
    errors.append(("invalid-index-" + str(i), catalog, index))
malformed = out / "malformed.mf4"
malformed.write_bytes(b"not an MDF file")
directory = out / "not-a-file"
directory.mkdir()
errors += [
    ("malformed-input", malformed, "0"),
    ("selected-unsupported", p / "analysis/catalog_fixture/unsupported.mf4", "1"),
    ("indexed-missing", out / "missing.mf4", "0"),
    ("indexed-directory", directory, "0"),
]
for name, file, index in errors:
    cp = invoke(name, inspect_js, [file, "--index", index])
    assert cp.returncode == 1 and cp.stdout == b"" and cp.stderr.endswith(b"\n"), (name, cp.stdout, cp.stderr)
    assert b"Traceback" not in cp.stderr
for name, file in [("legacy-missing", out / "missing.mf4"), ("legacy-directory", directory)]:
    cp = invoke(name, inspect_js, [file])
    assert cp.returncode != 0 and cp.stdout == b"" and cp.stderr
assert all(hashlib.sha256(Path(name).read_bytes()).hexdigest() == digest for name, digest in before.items())
report = {
    "status": "pass", "selected_indices": chosen, "indexed_cases": indexed_cases,
    "original_record_bytes": payload.hex(), "raw_record_count": len(records),
    "independent_uint64_values": list(map(str, unsigned)), "legacy_cases": len(legacy_cases) + 2,
    "indexed_error_paths": len(errors), "unchanged_io_error_paths": 2, "original_sources_unchanged": True,
    "compiled_inspector_sha256": hashlib.sha256(inspect_js.read_bytes()).hexdigest(),
    "compiled_catalogue_sha256": hashlib.sha256(channels_js.read_bytes()).hexdigest(),
    "commands": commands, "source_hashes": before,
    "reference": "Literal owned records and values; Python struct/strict JSON; no product parser imported",
}
(out / "verification.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(json.dumps({key: report[key] for key in ["status", "selected_indices", "raw_record_count", "legacy_cases", "indexed_error_paths", "unchanged_io_error_paths", "compiled_inspector_sha256"]}))
