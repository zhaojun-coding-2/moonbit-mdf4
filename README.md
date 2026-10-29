# MDF4 for MoonBit

`zhaojun-coding-2/mdf4` is a MoonBit library for finalized **MDF 4.10/4.11 fixed-record measurements**. It reads record/block layouts, retains exact integer bits and validity, applies six conversion categories, and aligns channels onto an explicit time grid. The core runs on JS and Wasm-GC without Python. A small Node CLI adapts local file I/O.

This is a bounded reader based on public ASAM descriptions and licensed implementation references. It is not a claim of full ASAM conformance, complete GES support, or official contest acceptance.

Module: `zhaojun-coding-2/mdf4`. Repository and current maintainer: [zhaojun-coding-2/moonbit-mdf4](https://github.com/zhaojun-coding-2/moonbit-mdf4). Original implementation and MIT copyright attribution to `zhaojun-coding`, Git history and upstream notices are preserved. Reproducible setup and the JS/Wasm-GC workflow are documented in [.ci/README.md](.ci/README.md) and [CI-PLAN.md](CI-PLAN.md).

## Run

Validated toolchain: `moon 0.1.20261023` with `moonc 0.10.17`; Node.js is used for the JS target. Dependency versions are pinned in `moon.mod` (zlib 0.21.17, io 0.23.20, flate 0.36.17; transitive versions/licenses are in THIRD_PARTY.md).

The retained validation used compatible local sources for those gmlewis modules as workspace members. The source archive excludes machine-specific `moon.work` paths, SDKs and dependency caches. When preparing an extracted checkout with local sources, create the same workspace shape, replacing these placeholders with the matching zlib, flate, hash, io and base64 module directories:

```powershell
moon work init . PATH_TO_ZLIB PATH_TO_FLATE PATH_TO_HASH PATH_TO_IO PATH_TO_BASE64
```

Use the checksum-pinned dependency workspaces in `.ci` for reproducible builds. The optional NyaCSV consumer is a separate module with its own pinned-source setup, described in `example/csv_consumer/README.md`.

```powershell
moon check --target js
moon test -p zhaojun-coding-2/mdf4 --target js
moon test -p zhaojun-coding-2/mdf4 --target wasm-gc
moon run example --target wasm-gc
moon run cmd/inspect --target js -- testdata/core-c2.mf4 linear
```

`example` is a runnable consumer of the public API. The final command prints JSON with exact raw integer strings, physical values, timestamps and a validity mask. Omit the channel name to list metadata. The CLI is JS-only; the library and example also run on Wasm-GC.

The checked-in fixtures are self-created, redistributable artificial measurements. Python is needed only to regenerate independent reference evidence, never for normal use or tests. `validation/` documents regeneration.

## Library use

Add `zhaojun-coding-2/mdf4` to a consumer's imports after making the local module available. The distribution here is a GitHub source checkout used through a local workspace; registry publication is separate.

```moonbit
match @mdf.open(file_bytes) {
  Err(error) => { /* handle header, layout or resource error */ }
  Ok(file) => match file.extract_channel("Speed") {
    Err(error) => { /* missing/ambiguous channel, unsupported conversion, etc. */ }
    Ok(series) => {
      // series.timestamps, series.values and series.valid have equal lengths.
      // Use @mdf.resample(series, raster, Previous or Linear) explicitly.
    }
  }
}
```

Use `file.channels()` and indexed `read_raw(index)` / `read_channel(index)` when names repeat. `RawValue::Unsigned` and `Signed` preserve all 64 bits; physical numeric values use Double and may round integers above 2^53. `extract_channel` returns `Series`, not `Array[Double]`: enumerations return `Label`, binary fields return `Data`, and invalid samples retain `valid=false`. Invalid samples are retained and converted; conversion domain errors remain errors. Header `start_ns()` stays UInt64; per-series timestamps are relative master seconds.

## Native record windows

`file.read_window(index, start_record, count) -> Result[RecordWindow, WindowError]` returns one atomic paired raw/physical snapshot of a selected channel. The index is the catalogue/global channel index; start/count refer to that channel group's original **demultiplexed record order**, not interleaved-file positions or a time interval. No raster, sorting, interpolation, unit conversion, sample dropping or time rebasing is applied.

`RecordWindow` carries `channel_index`, `start_record`, `record_count`, exact UInt64 `start_ns`, `raw`, and an existing `Series` (`name`, `unit`, `values`, `timestamps`, `valid`). The raw and three Series arrays have exactly `count` entries. Invalid selected values remain present and are still converted. Raw integers retain exact bits; physical numbers keep the existing Double semantics. Result arrays are fresh; Bytes values are immutable in the pinned SDK and can safely be shared between raw/physical values.

```powershell
moon run example/window --target js
moon run example/window --target wasm-gc
```

This separately compiled public-API receiver requests native record 1/count 1 of catalogue index 3 in the owned calibrated fixture: raw -99, Label 倒车, physical master time 11.5, valid=true, with origin 18446744073709551615 unchanged.

Ranges require `start_record >= 0`, `count >= 0`, `start_record <= N`, and `count <= N - start_record` without an overflowing sum. End-position empty windows are valid; positions beyond N are invalid even for count 0. `WindowError::InvalidRange(start,count,available)` is a caller range error. `WindowError::Source(MdfError)` preserves actual channel/metadata/sample errors; the old MdfError enum is unchanged. Channel validation precedes range validation, then the unique group master and selected/master conversion metadata are checked in the old order, even for an empty window. Only selected records undergo master decode/conversion/finite/valid checks, selected raw decode, conversion and validity checks. An error returns no partial window.

Normal `open` still reads/validates/decompresses the full file, copies all group records and enforces its original structure/resource limits. After open, the new operation decodes/converts only the requested k records and constructs only their result arrays, with the normal metadata lookup/setup cost. It does not provide lazy file I/O, avoid decompression/record storage, guarantee constant total memory, or claim a measured speedup.

A successful window does not certify that unselected records are physically readable. A known sample-level domain, UTF-8 or master-validity error outside a window can be avoided; including that record returns its existing source error. The old whole `read_raw`/`read_channel`/`extract_channel` behavior remains unchanged. Full-file structural/budget failures still occur at open even if a requested window would avoid that location. See `validation/check_window.py` for independent original-byte and actual public-receiver checks.

## Saved native window handoff

The Node [native handoff command](cmd/native_handoff/README.md) replays an ordered
saved list of group-native record windows from one content-pinned measurement.
It saves typed raw/physical values, native clock bit patterns and validity flags,
including invalid values, duplicates, overlap and empty windows, plus a separate
source/request/result SHA-256 receipt. The Python stdlib saved-file receiver
checks exact bytes and protocol consistency; independent complete literal/byte
cases separately check sample correctness. This adds a file delivery workflow
using the existing public APIs, without changing the single-window, alignment
or CSV contracts. See the command documentation for its 4096-window/1,000,000
returned-occurrence limits, units, exclusive receipt creation and I/O boundaries.

## UTF-16 fixed-record text

Fixed string sample types 8 (UTF-16 LE) and 9 (UTF-16 BE) use the existing `RawValue::Text` / physical `Label` path. This adds two field encodings within the same supported MDF 4.10/4.11 fixed-record scope; it adds no format, CLI flag or scientific conversion. Channel type selects byte order. A single zero byte in an ASCII code unit is data: termination occurs at an aligned `0000` code unit, or the whole bounded field is decoded if there is no terminator. Leading FEFF content is preserved, without guessing/switching byte order or lossy replacement.

```powershell
moon run example/utf16 --target js
moon run example/utf16 --target wasm-gc
moon run cmd/inspect --target js -- testdata/utf16.mf4 --index 1
moon run cmd/export --target js -- testdata/utf16.mf4 "0,1,2,3,4,5" le 1 previous be 2 previous --receipt utf16-receipt.json > utf16.csv
python validation/verify_export.py testdata/utf16.mf4 utf16.csv utf16-receipt.json
```

The owned six-record 4.11 sample includes ASCII, 龙🧪, valid empty text, quotes/newline, 月兔 and eight digits in both byte orders. Raw/physical strings are retained even when an invalidation bit is set; CSV still suppresses invalid fields while preserving valid empty text. Origin remains exact UInt64 maximum, source clocks/units/order and all existing CSV/schema/receipt rules remain unchanged. The public example and real-file inspector/export receivers check complete outputs against hand code units and independent CSV/byte expectations; no third-party adoption is claimed.

UTF-16 requires bit offset zero and a bit count divisible by 16. Ill-formed surrogate sequences before the first aligned NUL return `CorruptedBlock("invalid UTF-16 sample")`; shape failures return the existing `InvalidBitField`, and field bounds use the old error path. There is no invalid-sample skipping. Latin-1/UTF-8/byte-array decoding is unchanged. VLSD, MIME and BOM-switched type 17 remain unsupported. `validation/generate_utf16_fixture.py NEW_DIRECTORY` reproduces only this owned fixture in a fresh directory; its copied ID header/program marker does not assert that an external generator validated the new blocks.

## Multi-channel analysis and CSV

The additive `zhaojun-coding-2/mdf4/analysis` package turns selected channels into one typed table on an explicit raster. This bridges MDF sampling/validity semantics to analysis tools. General table and CSV tools already exist, including [MoonFrame](https://github.com/ihb2032/MoonFrame) and [NyaCSV](https://mooncakes.io/docs/moonbit-community/NyaCSV); this package focuses on MDF selection, per-column interpolation and retained validity.

### Find channels before exporting

For an unfamiliar file, run `moon run cmd/channels --target js -- YOUR_FILE.mf4`. It prints a versioned JSON catalogue with explicit global `index`, channel `group`, `name`, `unit`, master/sync codes and raw storage type/bit count. The indices are accepted directly by `read_channel`, analysis requests and export. Duplicate names stay separate; channel order is unchanged. For example, two channels named `速度🚲` can be distinguished by group and km/h versus m/s units:

```powershell
moon run example/catalog --target wasm-gc
moon run cmd/channels --target js -- analysis/catalog_fixture/catalog.mf4
moon run cmd/inspect --target js -- analysis/catalog_fixture/catalog.mf4 --index 3
moon run cmd/export --target js -- analysis/catalog_fixture/catalog.mf4 "0,0.25,0.5,0.75,1" ms 3 previous kmh 1 previous --receipt selected.json > selected.csv
python validation/verify_export.py analysis/catalog_fixture/catalog.mf4 selected.csv selected.json
```

Those indices belong to the supplied fixture; use the catalogue of your own file when selecting. `@analysis.channel_catalog_json(file)` supplies the same JSON on JS/Wasm-GC after opening a file. It reports exact UInt64 origin as a string, preserves empty inventories and reads existing metadata without executing physical channel conversion. Raw storage codes do not determine the converted Value kind or choose an interpolation policy. Unit text follows the root API; no XML interpretation or unit conversion is added. The CLI still uses the existing in-memory `open` and its data validation/resource limits. It is not a header-only scan, does not choose a raster and does not certify that every listed channel can be read physically.

The explicit three-argument form `inspect FILE --index INDEX` selects the catalogue's non-negative decimal global index and returns the existing complete raw/physical sample JSON, with original source clocks and validity. For the owned fixture above, index 3 selects m/s and index 1 selects km/h despite their identical names. No alignment, sorting, dropping invalid samples or unit conversion is added. Floating raw strings and numeric JSON retain their old spelling, including normalization of a source negative zero to 0; raw integer strings retain their full precision. `inspect FILE` metadata and `inspect FILE CHANNEL` retain their output and name-ambiguity behavior; in the two-argument form, even `--index` remains a literal channel name. Invalid new indices and selected read/conversion failures return nonzero/stderr without partial JSON. See `validation/check_inspect.py` for a runnable catalogue-to-inspection consumer.

### Inspect the chosen source

`moon run cmd/summary --target js -- YOUR_FILE.mf4 INDEX` reads the chosen global index and prints physical Value kinds, original sample/validity counts, source-order clock endpoints and a strict-time-order flag. It closes the gap between raw catalogue metadata and choosing an explicit raster/policy. For example, the catalogue below still describes signed-integer storage, while the selected source converts to text labels and has calibrated endpoints `10.5,11.5`:

```powershell
moon run example/summary --target wasm-gc
moon run cmd/channels --target js -- analysis/summary_fixture/calibrated.mf4
moon run cmd/summary --target js -- analysis/summary_fixture/calibrated.mf4 3
moon run cmd/export --target js -- analysis/summary_fixture/calibrated.mf4 "10.5,11.5" state 3 previous --receipt state.json > state.csv
python validation/verify_export.py analysis/summary_fixture/calibrated.mf4 state.csv state.json
```

`@analysis.channel_summary_json(file, index)` returns the JSON in a Result and propagates the existing MdfError on selected-read failure. Value kinds cover **all converted source samples**, including invalid ones. Empty sources have no observed kind and explicit null endpoints. Clock strings round-trip the reader's actual Double endpoints, including `-0`; exact UInt64 origin stays separate. Endpoints retain original order, so they are not min/max when `strict_time_order=false`. Empty/single sources have strict order. Counts/endpoints do not reconstruct the full or a uniform raster: the example explicitly chooses only endpoints and Previous. No sorting, row dropping or automatic policy is added. Use `read_channel(index)` for full values/timestamps. The summary still performs the existing in-memory physical read and its validation/limits.

### Align selected channels

For a long or saved explicit raster, pass a quoted `"@PATH"` in the same RASTER position. The UTF-8 file (optional BOM) contains a JSON array of decimal clock strings, for example `["10.5","10.625","10.9","11.5"]`. This avoids putting every point in process arguments; it does not generate a regular grid. A measured 4096-point irregular raster exceeded Windows process argument capacity before Node started, while the file form exported all points within the unchanged cell budget.

```powershell
moon run example/raster --target wasm-gc
moon run cmd/export --target js -- analysis/summary_fixture/calibrated.mf4 "@example/raster/grid.json" state 3 previous --receipt raster.json > raster.csv
python validation/verify_export.py analysis/summary_fixture/calibrated.mf4 raster.csv raster.json
```

The file format uses **strings**, not JSON numbers: they follow the same existing binary64 number parser as inline clocks and preserve `-0`. Actual points must be finite and strictly increasing; `[]` is accepted. The path resolves from the working directory. `@` is checked only in RASTER, so labels and old inline/empty-raster forms retain their meaning. `@analysis.parse_raster_json(text)` supplies the same parsing contract on JS/Wasm-GC. Input/JSON/table processing remains in memory, with existing alignment cell limits; receipt format is unchanged and its CSV fingerprint includes the interpreted time column, without separately fingerprinting the raster file.

```powershell
moon run example/table --target wasm-gc
moon run cmd/export --target js -- testdata/unsorted.mf4 "0,0.25,0.5,0.75,1" held 1 previous sensor 3 linear > aligned.csv
```

The pure example prints a JSON report containing the CSV, row/column counts and exact origin. The Node command writes CSV only to stdout. Its arguments are `FILE RASTER LABEL INDEX POLICY [LABEL INDEX POLICY ...]`: the raster is comma-separated relative seconds; channel indices are zero-based positions in `file.channels()` (the inspect metadata name array has that order); policies are `previous` or `linear`. Indices distinguish repeated source names, and labels distinguish output columns. No time re-zeroing, row dropping or extrapolation occurs.

Add `"zhaojun-coding-2/mdf4/analysis" @analysis` alongside the root import. After opening the fixture above:

```moonbit
match @analysis.align(file, [
  { channel: 1, label: "held", policy: @mdf.Previous },
  { channel: 3, label: "sensor", policy: @mdf.Linear },
], [0.0, 0.25, 0.5, 0.75, 1.0], max_cells=10000) {
  Ok(table) => {
    // table.columns() retains typed values, validity, source name/unit/index.
    // table.start_ns() remains UInt64; returned grid/column arrays are snapshots.
    println(table.to_csv())
  }
  Err(error) => { /* InvalidRequest, CellLimit or labelled source-channel error */ }
}
```

### Replay a saved analysis query

Save the complete input query when the raster, ordered channel selections, aliases, interpolation and gap policy must travel together. `@analysis.align_query(file, query_json, max_cells=1000000)` returns the existing `AlignedTable` with the existing `AnalysisError`; it executes the same alignment operations. The versioned document has exactly four fields:

```json
{
  "query_version": "mdf4.analysis.query/1",
  "raster": ["10.5", "10.75", "11.25", "11.5"],
  "columns": [{ "channel": "3", "label": "state 🚦", "policy": "previous" }],
  "max_gap_seconds": "0.25"
}
```

```powershell
moon run example/query --target js
moon run example/query --target wasm-gc
moon run cmd/export --target js -- analysis/summary_fixture/calibrated.mf4 --query example/query/request.json --receipt query-receipt.json > query.csv
python validation/verify_export.py analysis/summary_fixture/calibrated.mf4 query.csv query-receipt.json
```

The supplied query emits four rows, retaining origin `18446744073709551615`, source name `速度🚲` and m/s. At 10.5/10.75 it emits 前进/true; 11.25 is blank/false because held age 0.75 exceeds 0.25; 11.5 is 倒车/true. An explicit null gap uses unrestricted alignment. The public example returns full CSV/schema and demonstrates a small caller-supplied cell budget; the Node file receiver verifies the complete saved CSV and existing receipt independently.

The file form is exactly `export FILE --query QUERY_FILE [--receipt NEW_PATH]`. Only the RASTER position selects it, so old inline/`@RASTER` forms and a column label literally named `--query` retain their behavior. Query files are UTF-8 with an optional single BOM. Raster points remain decimal strings with existing finite/order/negative-zero/empty rules. Ordered columns have exactly `channel`, `label`, `policy`; channel is an ASCII decimal digit string in nonnegative Int32 range (leading zeros allowed), labels follow old uniqueness rules, and policies are `previous`/`linear`. `max_gap_seconds` must be null or a finite nonnegative decimal string. Missing/unknown fields and wrong types are errors. Duplicate-key handling follows the pinned core JSON parser; duplicate detection is not promised.

Query file I/O/UTF-8 precedes normal MDF open; after readable query text, source-open errors precede query semantic errors. The query adds no source/output paths, includes, nested raster files, batch processing, automatic channel matching or CLI gap override. Indices belong to the chosen file's catalogue. The logical-cell budget stays separate and the file mode uses the same default. Open, physical reads, memory limits, numerical semantics and CSV/schema/receipt bytes are unchanged. Receipts bind source and interpreted CSV, not raw query spelling, and retain exclusive creation before CSV emission. This is a complete saved input workflow, with no third-party adoption claim.

CSV columns are `start_ns,time_s`, then each `label [unit]` value and its `__valid` companion; brackets are omitted for empty units. Invalid/outside-domain cells are blank/false, while valid empty labels are blank/true. Exact origin integers are decimal text; numeric NaN/Infinity remain textual when their record validity is true. Byte values use lowercase `0x` hex. Fields are quoted, embedded quotes doubled, and records use CRLF. This is data interchange: spreadsheet formula neutralization and an MDF round-trip encoding are outside this export contract.

Labels and generated headers must be unique, Linear requires numeric samples, and grid times must be finite/strictly increasing. Empty grids produce a header-only CSV. The default 1,000,000-cell limit bounds rows times selected columns before extraction; it does not bound total bytes or serialized text. The reader, aligned arrays and CSV string are held in memory. The separate AnalysisError leaves existing MdfError matches compatible. See [analysis/README.md](analysis/README.md) for the exact new API and schema.

New acceptance: 7 analysis groups plus 18 selected 05-07 regression groups passed on both JS and Wasm-GC (25 per target); both example reports match an independent five-row table. Python's standard CSV reader validated five file-export scenarios/18 data rows and ten CLI error paths, including Unicode/quotes/newlines, binary values, valid empty labels and UInt64 maximum origin. No new runtime dependency was added, and no MoonFrame runtime integration or remote publication is claimed.

### Bound stale interpolation

Use the additive `@analysis.align_with_gap(file, requests, raster, max_gap=0.25)` when held data or a long interpolation bracket must stop being considered valid after 0.25 seconds. `Previous` limits the age since the held observation; `Linear` limits the full bracketing source interval. Equality is allowed. Distances are compared exactly for the actual binary64 endpoints and cap, including when ordinary subtraction would round an over-limit distance onto the boundary. Exact observations retain their source validity, and an invalid source sample is never made valid. The same finite nonnegative limit applies to all selected columns; zero allows only exact observations. `table.max_gap()` returns `Some(seconds)` for this operation and `None` for the original `align`, whose signature and unrestricted behavior remain unchanged.

```powershell
moon run example/gaps --target wasm-gc
moon run cmd/export --target js -- testdata/unsorted.mf4 "0,0.125,0.25,0.375,0.5,0.625,0.75,0.875,1" held 1 previous sensor 3 linear --max-gap 0.25 > limited.csv
```

The pure example compares unrestricted and limited CSV on the same nine-row grid. Opted-in gap rejection changes validity to false and CSV cells to blank; typed computed values, requested rows, units and exact origin remain available. The trailing CLI option preserves the old positional form, including a column label literally named `--max-gap`.

Numeric CSV formatting retains `-0` for negative-zero values and requested times. Independent binary64 readback covers signed zero, subnormal values and maximum finite values; `validation/check_gaps.py` checks complete saved CSV records, masks and error paths.

### Review an exported table

Plain CSV can give a numeric value and an enum label the same text, and it does not record selected channel indices or interpolation settings. `table.schema_json()` adds a versioned MDF analysis description: source indices/names/units, aliases, policies, gap cap, exact origin, row counts, validity counts and observed kinds of valid values. It runs on both JS and Wasm-GC. Empty/all-invalid columns report no observed kind rather than guessing their type.

The Node exporter can optionally create a JSON receipt binding that schema to the SHA-256 and byte length of the loaded MDF source and the exact UTF-8 CSV:

```powershell
moon run example/receipt --target wasm-gc
moon run cmd/export --target js -- analysis/review_fixture/mixed.mf4 "0,0.5,0.75,1" number 1 linear state 2 previous bytes 3 previous --max-gap 0.5 --receipt review.json > review.csv
python validation/verify_export.py analysis/review_fixture/mixed.mf4 review.csv review.json
```

Use a new receipt path: `--receipt` refuses an existing file and creation errors emit no CSV. It accepts either order with trailing `--max-gap`; without it, no sidecar is created and CSV output is unchanged. The shell controls the redirected CSV file and its overwrite/encoding behavior; the verifier checks the bytes actually saved. The receipt is written before stdout emission, so its existence alone does not prove a complete saved CSV. It supplies content fingerprints and consistency checks, without a signature or a reversible MDF encoding. The paired CSV holds the full raster; the schema holds its count and endpoints.

The saved-byte verifier accepts legal text fields beyond Python CSV's default field ceiling. After checking the actual file fingerprints, it temporarily bounds CSV parsing by the actual saved byte length and restores the caller's previous parser setting on success or error. Quoting, UTF-8 text and validity checks are preserved; this does not change the MDF reader or alignment budgets. See `validation/check_long_fields.py` for a reproducible long-text export and strict-error check.

The verifier also checks every record separator against the receipt's `newline: "CRLF"`, including interior records when the file still ends in CRLF and its fingerprint matches. Bare LF/CR inside quoted fields, doubled quotes and literal quotes in unquoted fields keep their existing meaning. Python's strict CSV parser checks syntax first; the extra representation check does not require every field to be quoted. Run `python validation/check_record_newlines.py NEW_CAPTURE_DIRECTORY` for eight frozen saved-file cases through both the CLI and imported verifier. See [CI-PLAN.md](CI-PLAN.md) for the required checks and evidence boundaries.

### Calibrated master clocks and selective reading

`read_raw(master_index)` retains raw clock samples; `Series.timestamps` uses the time master's physical conversion before alignment. For a master with raw times `0,1` and CC1 conversion `2*x+5`, supply raster times in the resulting `5,7` coordinate system. A linear bracket spans two physical seconds, so an interior point fails `max_gap=1.5` even though the raw clock difference is one. The exact HD origin stays separate and unchanged. A zero-scale conversion can yield duplicate physical times: raw/Series extraction remains available, while alignment returns `InvalidTime` through the labelled channel error.

Physical conversion is performed for requested channels and their time master. An unsupported conversion on another channel sharing the records does not block a valid selection. That channel's raw access remains available; selecting it physically returns `UnsupportedConversion`, and an export failure emits no CSV or optional receipt.

## Supported contract

- ID and HD/DG/CG/CN/CC/TX data paths; DT, DZ, HL/DL concatenation; fixed sorted records and unsorted record IDs of 1/2/4/8 bytes. Counts, spans, chains and limits are checked.
- Integer widths 1–64, bit offsets 0–7, LE/BE and two's-complement, including fields spanning nine bytes. This is MDF offset arithmetic, not CAN DBC sawtooth numbering. IEEE Float32/64 LE/BE, Latin-1/UTF-8/UTF-16 LE/BE fixed strings and fixed byte fields are readable. CN composition links are traversed; channel-array (CA), VLSD/virtual/MLSD and other sample types are explicitly unsupported when encountered/read.
- CC: identity (0), linear (1), rational (2), algebraic expression (3), interpolated table (4), value-to-text enum (7, TX references and default text). Other conversion codes remain accessible through the separate raw API; physical conversion returns `UnsupportedConversion`. Nested enum conversion references are not evaluated.
- Formula grammar: finite decimal/exponent literals; `X`, `X1`, `PI`, `pi`, `e`; parentheses; unary `+/-`; binary `+ - * / ^ **` (right-associative power, above unary minus); `sin cos tan asin acos atan exp ln log log10 sqrt abs floor ceil`, plus two-argument `min max pow`. `log` is natural log. Unknown names, invalid syntax, non-finite/domain results and limits return `InvalidFormula`. This is an explicit mathematical subset, not full GES.
- DZ mode 0/1: RFC1950 zlib/Deflate, checksum read through EOF, exact output size, inverse byte transpose and untransposed tail remainder.
- Record invalidation bits and always-invalid channels are preserved. A unique valid time master (`kind=2`, `sync=1`) is required to produce a series. Other master kinds are not silently interpreted as time. Extraction retains record order; alignment rejects duplicate, reversed or non-finite time.
- Resampling: strictly increasing finite source/grid; `Previous` or numeric `Linear`. Outside the source domain yields `valid=false` and a NaN placeholder; invalid interpolation endpoints yield `valid=false`. Enums require `Previous`; no extrapolation or silent row deletion. Empty signals yield an invalid aligned series.

No writer, 4.2 column storage, bus database decoder, or universal unfinished-file repair is included. An `UnFinMF` identifier or pending finalization flags returns `UnfinalizedFile` before traversal. Unknown metadata that is not needed for these data paths is not evaluated. Unit text is read from the CN unit link; XML metadata is exposed as text, not a full semantic XML model.

`open(bytes, limits=...)` is an in-memory API, not streaming file I/O. Default limits are 64 MiB decoded data per DG, 100,000 topology/data blocks per traversal and 1,000,000 total records. Address bounds are checked before narrowing to host indices. Limits do not promise total peak allocation equal to max_output: input bytes, copied records and returned series also occupy memory.

## Validation and provenance

The [GitHub Actions workflow](https://github.com/zhaojun-coding-2/moonbit-mdf4/actions) runs real JS/Wasm-GC compiler checks, builds, tests, public examples and independent consumers. [CI-PLAN.md](CI-PLAN.md) describes the required gates and retained source/compiled/output identities. The standalone [CSV consumer](example/csv_consumer/README.md) is a separate owned module that imports the public library and analysis packages and consumes CSV/schema through a pinned upstream NyaCSV source.

Committed artificial fixtures and independent literal/byte expectations cover the supported layouts, six conversion categories, masks, numeric boundaries, native windows, saved queries and fixed text. Normal library use and MoonBit tests do not require Python or an external MDF implementation. Optional reference reproduction and the actual saved-file consumers are documented in [validation/README.md](validation/README.md).

The 256 bit-field reference vectors include 200 exact scalar asammdf comparisons; the remaining 56 use independent Python arbitrary-precision byte-integer arithmetic because the external API returned arrays, overflowed or rounded raw integers. These are separate evidence categories, not 256 successful asammdf comparisons. No global conversion error bound or complete ASAM conformance is claimed.

A CSS Electronics device recording was tested locally: the original `UnFinMF 4.11` was rejected; an independently finalized asammdf output then matched 8 scalar channels / 14,520 samples in raw values, masks, time and physical values. The preprocessing is external to this library. No CSS recording or DBC is distributed here and **CC-BY4 was not established**. See THIRD_PARTY.md for data provenance and the distinction between local evaluation and redistribution.
