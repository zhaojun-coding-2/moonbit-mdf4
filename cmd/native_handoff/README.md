# Saved native window handoff

This Node command uses the public MoonBit `open` / `read_window` APIs to review
ordered native record windows from one finalized MDF 4.10/4.11 byte image. It
keeps each group's own physical master clock, raw and physical values, and every
validity flag. It supplies a saved selection, typed result, byte-binding receipt
and an independent saved-file receiver. It adds no sampling algorithm or public
batch API.

Build from the repository root:

```sh
moon build --target js
node _build/js/debug/build/zhaojun-coding-2/mdf4/cmd/native_handoff/native_handoff.js analysis/catalog_fixture/catalog.mf4 example/native_handoff/request.json --receipt native-receipt.json > native-result.json
python validation/verify_native_handoff.py analysis/catalog_fixture/catalog.mf4 example/native_handoff/request.json native-result.json native-receipt.json
```

Use a shell that preserves native stdout bytes. Older Windows PowerShell can
re-encode redirection; this portable Python alternative saves the exact bytes:

```python
from pathlib import Path
import subprocess
result = subprocess.check_output([
    "node", "_build/js/debug/build/zhaojun-coding-2/mdf4/cmd/native_handoff/native_handoff.js",
    "analysis/catalog_fixture/catalog.mf4", "example/native_handoff/request.json",
    "--receipt", "native-receipt.json",
])
Path("native-result.json").write_bytes(result)
```

Choose a new receipt path for each invocation. The sample request identifies
the committed artificial measurement by exact source SHA-256 and byte length.
It preserves seven entries/eight returned record occurrences, including different
groups of the same-named signal, overlap, a repeated entry, a legal empty window
and a master selection. The invalid raw/physical value 6 is retained twice.
The two group clocks are `[0,1]` and `[0.25,0.75]`; their stored master units are
empty. These observations do not infer Hz, seconds, a uniform rate or a raster.

## Request (`mdf4.native-window.request/1`)

The exact object fields are `request_version`, `source`, `windows`. `source`
contains `bytes` (canonical nonnegative decimal string) and lowercase `sha256`.
Each ordered window has exactly `channel_index`, `expected_group`, `start_record`,
`record_count`, all canonical nonnegative decimal strings fitting Int32. Indices
are global within the pinned source; `expected_group` asserts the actual group,
and start/count address that group's demultiplexed records. They are not byte
offsets, seconds or group-local channel indices. Unknown fields are rejected.

An empty request list and end-of-group count-zero windows are legal. Repeated
and overlapping entries are retained in their original order. JSON must be
strict UTF-8, optionally with a leading BOM. Object duplicate members use
JSON.parse's last-member-wins interpretation; repeated array entries are never
deduplicated. The receipt fingerprints the original request bytes, including
BOM and whitespace, rather than a reserialized document.

The new handoff limits are 4096 windows and 1,000,000 summed returned record
occurrences, counting repetitions. They are checked before collection. They
do not change `read_window` or `open` limits, and do not bound JSON byte size or
total peak memory. There are no adjustable limits or alternate input modes.

## Result (`mdf4.native-window.result/1`)

Top fields are `result_version`, `file`, `windows`. `file` contains the stored
`version` and exact UInt64 `start_ns` decimal string. Each window contains:

- `ordinal`, global `channel_index`, actual `group_index`, global
  `master_channel_index`, `name`, `unit`, stored `master_unit`, `start_record`,
  `record_count` and `time_unit: "native_master_physical"`.
- Four parallel arrays of exactly record_count entries: `time_bits`, `raw`,
  `values`, `valid`. Empty windows still contain metadata and four empty arrays.

All metadata integers are canonical decimal strings. Time and floating values
use exactly 16 lowercase hexadecimal digits for the returned Double bit value.
Native clocks must be finite; their order, repeats, reversal, negative values
and negative zero are preserved. No normalization, sorting, origin addition or
rebasing occurs. Empty master units remain empty.

| Array | Tagged scalar |
|---|---|
| raw | `{"kind":"unsigned","decimal":"..."}` (UInt64) or signed (Int64) |
| raw | `{"kind":"real","bits":"..."}`, text with `text`, octets with `hex` |
| values | `{"kind":"number","bits":"..."}`, label with `text`, data with `hex` |

Hex bytes are lowercase and even-length; empty text/bytes are legal. All values
are retained under `valid: false`. Existing Identity nonfinite Number/Real values
are represented as bits rather than nonstandard JSON numbers. Integer raw values
stay exact; physical Double can round beyond 2^53. Floating bits describe the
returned value, not original MDF byte order or every signaling-NaN payload.
The serializer emits compact UTF-8 JSON in the documented field order and one LF.

## Receipt and independent receiver

`mdf4.native-window.receipt/1` has exactly `receipt_version`, `source`, `request`,
`result`, `result_version`, `window_count`, `returned_record_count`. Each content
binding contains decimal-string `bytes` and lowercase `sha256`; result also has
`encoding: "UTF-8"`. Counts include duplicate/overlapping returned occurrences.
The source and request are read once. The same loaded source buffer is hashed
and opened once, and the complete collection must succeed before a receipt is
exclusively created and result bytes are emitted. Later range/sample errors,
group/identity/representation/budget failures emit no successful result prefix
and create no receipt. Existing receipts are never overwritten.

The Python stdlib receiver checks the four actual saved byte images, exact
fields/types/versions, ordered request correspondence, all typed vectors,
finite clocks, masks, group/master metadata, repeated source-record consistency
and counts. It does not require a monotonic native clock. Its importable
`verify(source_bytes, request_bytes, result_bytes, receipt_bytes)` has the same
checks as the CLI. Its fingerprint/consistency check does not independently
decode arbitrary MDF, authenticate a signer or establish the semantic truth of
otherwise consistent values. Complete owned-byte/literal expectations validate
that separate claim in `validation/check_native_handoff.py`.

This is a loaded-buffer consistency guarantee, not OS-level atomic acquisition
or file locking. A receipt is written before stdout and binds the intended result
bytes; it does not prove that a redirect or pipe saved them. I/O failure may
leave an incomplete new receipt or result. The command fails, and the receiver
checks actual saved files; there is no two-file atomic filesystem transaction.
The original source, single-window API, aligned CSV/schema/receipt versions and
their numerical/error contracts remain unchanged. No streaming or speedup is
claimed. No external adoption or ASAM conformance certification is implied.
