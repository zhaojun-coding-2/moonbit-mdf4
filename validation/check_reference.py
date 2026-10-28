"""Re-read the committed artificial files with an independent external parser.
No product code is imported. Does not regenerate expected values from MoonBit.
"""
import hashlib
import json
import math
from pathlib import Path

import asammdf
from asammdf import MDF

assert asammdf.__version__ == "8.8.28"
root = Path(__file__).resolve().parents[1]
here = root / "validation"
for row in json.loads((here / "INPUTS.json").read_text()):
    assert hashlib.sha256((root / row["file"]).read_bytes()).hexdigest() == row["sha256"]
gold = json.loads((here / "core-golden.json").read_text())
for mode in (0, 1, 2):
    with MDF(root / f"testdata/core-c{mode}.mf4") as reader:
        for name, expected in gold.items():
            signal = reader.get(name, ignore_invalidation_bits=True)
            actual = [v.decode() if isinstance(v, bytes) else float(v) for v in signal.samples.tolist()]
            for a, b in zip(actual, expected["values"], strict=True):
                assert a == b if isinstance(b, str) else math.isclose(a, b, abs_tol=1e-10, rel_tol=1e-12)
            assert signal.timestamps.tolist() == expected["timestamps"]
            assert signal.invalidation_bits.tolist() == expected["invalid"]
bit = json.loads((here / "bit-boundaries-golden.json").read_text())
with MDF(root / "testdata/bit-boundaries.mf4") as reader:
    for name in bit["asammdf_scalar_checked"]:
        value = int(reader.get(name, raw=True, ignore_invalidation_bits=True).samples[0])
        assert value == bit["values"][name]
    for limitation in bit["oracle_limitations"]:
        name = limitation["name"]
        _, typ, offset, width = name.split("_")
        typ, offset, width = map(int, (typ, offset, width))
        # Independent arbitrary-precision arithmetic; product extracts bit by bit.
        raw = bytes.fromhex("d3e5a781019afac37f")[: (offset + width + 7) // 8]
        value = (int.from_bytes(raw, "big" if typ % 2 else "little") >> offset) & ((1 << width) - 1)
        if typ >= 2 and value & (1 << (width - 1)):
            value -= 1 << width
        assert value == bit["values"][name]
unsorted = json.loads((here / "unsorted-golden.json").read_text())
with MDF(root / "testdata/unsorted.mf4") as reader:
    for name, expected in unsorted["truth"].items():
        signal = reader.get(name, raw=True, ignore_invalidation_bits=True)
        assert signal.samples.tolist() == expected["raw"]
        assert signal.timestamps.tolist() == expected["time"]
    assert reader.get("g0", raw=True, ignore_invalidation_bits=True).invalidation_bits.tolist() == [False, True]
print("PASS: hashes, six CC/three layouts, 200 asammdf scalar bit vectors, 56 integer-arithmetic vectors, unsorted records")
