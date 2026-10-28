"""Independent standard-Python CSV/JSON expectations for actual example output."""
import csv
import io
import json
from pathlib import Path
import sys


def rows(text):
    return list(csv.reader(io.StringIO(text, newline=""), strict=True))


def cell(kind, text):
    return {"kind": kind, "text": text}


def main():
    folder = Path(sys.argv[1])
    raster = json.loads((folder/"raster.json").read_bytes())
    schema = json.loads(raster["schema_json"])
    assert schema["row_count"] == 4 and schema["start_ns"] == str(2**64-1)
    expected = [["start_ns", "time_s", "state [m/s]", "state [m/s]__valid"]]
    expected += [[str(2**64-1), t, label, "true"] for t, label in [
        ("10.5", "前进"), ("10.625", "前进"), ("10.9", "前进"), ("11.5", "倒车")]]
    assert rows(raster["csv"]) == expected

    receipt = json.loads((folder/"receipt.json").read_bytes())
    expected = [["start_ns", "time_s", "number [u]", "number [u]__valid", "state [u]", "state [u]__valid", "bytes [u]", "bytes [u]__valid"]]
    expected += [[str(2**64-1), *values] for values in [
        ["0", "1", "true", "1", "true", "0x000000000000f03f", "true"],
        ["0.5", "", "false", "1", "true", "0x000000000000f03f", "true"],
        ["0.75", "", "false", "", "false", "", "false"],
        ["1", "2", "true", "2", "true", "0x0000000000000040", "true"],
    ]]
    assert rows(receipt["csv"]) == expected
    assert json.loads(receipt["schema_json"])["max_gap_seconds"] == "0.5"

    native = json.loads((folder/"native.json").read_bytes())
    assert [c["name"] for c in native["cases"]] == ["labels", "mixed", "nonfinite", "all invalid"]
    expected_native = {
        "labels": {"times": ["0", "0.25", "0.75", "1"], "rows": [[None], [cell("label", '状态,"就绪"\n第二行')], [cell("label", "")], [None]]},
        "mixed": {"times": ["0", "1"], "rows": [
            [cell("number", "1"), cell("label", "1"), cell("data", "0x000000000000f03f")],
            [cell("number", "2"), cell("label", "2"), cell("data", "0x0000000000000040")]]},
        "nonfinite": {"times": ["-0", "0.1", "0.2"], "rows": [[cell("number", "NaN")], [cell("number", "Infinity")], [None]]},
        "all invalid": {"times": ["0", "1"], "rows": [[None], [None]]},
    }
    for case in native["cases"]:
        decoded = rows(case["csv"])
        assert decoded[0] == case["parsed_header"] and decoded[1:] == case["parsed_rows"]
        expected = expected_native[case["name"]]
        assert case["view"]["times"] == expected["times"] and case["view"]["rows"] == expected["rows"]
        assert case["view"]["start_ns"] == ("1793120324061712896" if case["name"] == "nonfinite" else str(2**64-1))
        if case["name"] == "labels":
            assert decoded[0][2] == "state 🚦"
        if case["name"] == "all invalid":
            assert case["view"]["columns"][0]["valid_value_kinds"] == []
    assert native["rejections"] == [
        {"name": "version", "error": "schema version"}, {"name": "header", "error": "header"},
        {"name": "row count", "error": "row count"}, {"name": "validity", "error": "validity"},
        {"name": "column union", "error": "ambiguous column kind"},
    ]
    print(json.dumps({"status": "pass", "rasterRows": 4, "receiptRows": 4, "nativeCases": 4, "nativeRows": 11, "nativeRejections": 5}))


if __name__ == "__main__":
    main()
