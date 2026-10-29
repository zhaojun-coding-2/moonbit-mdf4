# Independent reference reproduction

## UTF-16 fixed sample receivers

`example/utf16` is a separately compiled public reader/alignment consumer on JS and Wasm-GC. Its raw/physical/window/mask report and complete CSV/schema are checked by `check_utf16.py example OUTPUT_JSON`. `check_utf16.py files COMPILED_INSPECT_JS COMPILED_EXPORT_JS NEW_CAPTURE_DIRECTORY` invokes the existing file CLIs and verifies full inspector objects and saved CSV/schema/receipt against original bytes, hand Unicode/code units and standard-library CSV/struct/hash readback. It covers both MDF4.10/4.11 headers, both endiannesses, surrogate bounds/failures, aligned NUL versus single zero bytes, BOM content, field limits, independent invalid bits, and unchanged Latin-1/UTF-8/bytes controls. No producer decoder/encoder supplies the oracle.

The new `generate_utf16_fixture.py NEW_DIRECTORY` is an optional stdlib-only reproducer for this one owned measurement; existing generators are not rerun by its checks. It copies the own baseline64-byte ID verbatim (4.11/411 and original program marker), constructs every later block/record with literal code units, and does not claim asammdf generated or runtime-validated this file. Source fixture bytes are preserved by all consumers.

## Saved query public and file receivers

`validation/check_query.py` uses only Python standard library, original owned input bytes, `struct`, literal metadata/cells and CSV/hash readback. It is not a decoder dependency or a producer-derived oracle. The shipped calibrated query's complete four rows include exact UInt64 origin, Unicode labels, an inclusive gap endpoint and a retained invalid row; mixed ordered columns add Data, numeric Linear, numeric-looking Label, negative-zero time and quote/comma/newline headers. Full schema and existing receipt source/CSV byte lengths and SHA-256 must agree. Old inline/`@RASTER` commands are separate compatibility controls, including labels literally named `--query`.

```powershell
moon run example/query --target js > query-example.json
python validation/check_query.py example query-example.json
moon build cmd/export --target js
python validation/check_query.py files _build/js/debug/build/zhaojun-coding-2/mdf4/cmd/export/export.js NEW_QUERY_CAPTURE_DIRECTORY
```

Use a new capture directory; it retains every command, stdout/stderr, query, receipt and final manifest. Query syntax/field/index/policy errors, old alignment errors, query I/O/UTF-8, source-open precedence, new-form errors and existing-receipt protection must not yield successful partial artifacts. Source/query files are read back unchanged. The independent public example checks also run on Wasm-GC; its small public `max_cells` call must return the old `CellLimit`. No reference generator is needed or run by these receivers.

Normal `moon test` needs only MoonBit and the committed fixture byte constants.
To independently re-read those same artificial files:

```powershell
python -m venv .reference-env
.\.reference-env\Scripts\python -m pip install -r validation/requirements.txt
.\.reference-env\Scripts\python validation/check_reference.py
```

The script validates `INPUTS.json` hashes before comparing external outputs to stored golden JSON. Fixture construction used self-specified raw samples and `asammdf 8.8.28 MDF.append/Signal/MDF.save` for three storage modes. The bit/unsorted files were written by a small layout writer from the MIT reference field definitions, then read by asammdf; no product parser was used to produce golden outputs. Generation scripts and first failing oracle attempts are retained in the execution receipt.

`bit-boundaries-golden.json` lists 200 scalar cases actually checked by asammdf and 56 cases where its API returned arrays, overflowed, or rounded large signed raw values through floating point. Those 56 use Python arbitrary-precision byte-integer arithmetic, an independent algorithm from the product's bit loop. These are separate claims. A library returning a rounded scalar is not accepted as the truth for exact 64-bit bits.

All files here and in `testdata/` are artificial and covered by the project MIT license. The actual CSS recording was checked only in the local execution directory, with an independently finalized copy and separate provenance. It is not part of this redistributable suite.


## Analysis-table acceptance

The new `analysis/fixture/` files are self-created derivatives of the existing artificial fixtures: Unicode/empty enum labels with UInt64 maximum origin, fixed byte fields, and valid non-finite IEEE values. Regenerate files, embedded MoonBit bytes and their manifest with `python validation/generate_analysis_fixtures.py` (standard Python only). It does not touch historical testdata files.

Build `moon build cmd/export --target js`, then run `python validation/check_analysis.py PATH_TO_COMPILED_EXPORT_JS`. The script uses Node for the actual file consumer and Python's independent standard csv parser. It checks all five fixture/raster/selection scenarios (18 data rows), literal expected values/masks/headers, Unicode quotes/newlines, byte hex, exact origin, valid empty strings, and ten error paths with nonzero exit/no stdout. Normal MoonBit tests use committed embedded bytes and do not call Python or download an oracle.


## Gap and finite-number CSV acceptance

`python validation/generate_gap_fixtures.py` builds additional MIT derivatives from the pinned self-created nonfinite fixture: binary64 roundtrip values/times, extreme finite clocks, and zero/single-record inputs. It writes only the additional files/embedded `gaps.mbt` and `gap-manifest.json`; historical fixtures stay unchanged.

After building cmd/export, `python validation/check_gaps.py PATH_TO_COMPILED_EXPORT_JS` independently checks 11 file/selection/raster scenarios (52 rows), six new error cases, and 11 finite value/time bit patterns. It covers held age vs full linear span, inclusive limits, exact observations, original invalid bits, zero caps, enums/empty labels, empty/single records, extreme clocks, and a literal --max-gap column alias. Run the existing check_analysis.py as well when changing CLI/CSV paths; together these covered 16 scenarios/70 data rows/16 error paths in the round-09 acceptance. The normal MoonBit tests remain offline and require no Python.


## Exact gap boundaries (round 10)

`python validation/generate_gap_precision.py` creates a separate precision_fixture package from the own roundtrip fixture. It retains both original counterexample files and adds unit/tiny-span files; no historical fixture/generator is overwritten. `python validation/check_gap_precision.py COMPILED_EXPORT_JS [CAPTURE_DIRECTORY]` checks 16 complete CSV scenarios/17 data rows with exact Fraction endpoint/query/cap comparisons, including the original Previous/Linear over-limit cases, true equality, neighboring caps, observations and tiny intervals. The optional directory records actual CSV bytes.

The new numerical matrix uses 149 fixed boundary tuples and constructs inputs from their UInt64 bits. This avoids an observed one-ULP decimal-literal conversion in the installed compiler; no case is removed or expected bit pattern changed. Tests use an independent exact rational reference. The existing check_gaps.py remains the related full export regression; unrelated unchanged reference collections are not repeated for this correction.

## Export review receipts (round 11)

`python validation/generate_review_fixture.py` creates the separate `analysis/review_fixture/` mixed file, embedded bytes and manifest using standard Python. It derives only from the project's own `precision_fixture/unit_span.mf4`, retaining two observations and adding text-enum and fixed-byte channels. Independent asammdf 8.8.28 readback of all three channels is recorded in the round-11 receipt; the generator itself requires no external package and leaves historical fixtures unchanged.

```powershell
moon test analysis/schema_wbtest.mbt --target js
moon test analysis/schema_wbtest.mbt --target wasm-gc
moon run example/receipt --target wasm-gc
moon build cmd/export --target js
python validation/check_receipts.py PATH_TO_COMPILED_EXPORT_JS NEW_CAPTURE_DIRECTORY
```

The capture directory must not already exist. The standard-Python harness runs the actual Node exporter and independently checks eight receipt exports/17 rows: numeric-versus-enum ambiguity, a mixed Number/Label/Data table, both trailing option orders, empty/all-invalid grids, Unicode/quotes/newlines/signed zero, and valid non-finite values. It checks literal complete-row expectations, source/CSV hashes, schema settings/counts/kinds, four controlled content/metadata mutations, five failure cases, and flag-like old column aliases. Existing receipt bytes must remain unchanged on refusal. Normal MoonBit tests use committed byte constants and require no Python, external oracle or downloads.

Verify a user's saved source/CSV/receipt separately:

```powershell
python validation/verify_export.py SOURCE_MF4 EXPORTED_CSV RECEIPT_JSON
```

This verifies SHA-256 and byte counts, UTF-8/CRLF representation, headers, complete rows, exact origin, ordered finite times, bounds, validity counts and observed-kind consistency. It does not reparse MDF or authenticate a signer. A changed receipt and changed payload can be made mutually consistent; the receipt is for content review, without a trust/signature protocol. The exporter exclusively creates only the JSON path; shell redirection controls the CSV path and encoding. Run the verifier against the bytes actually saved, because writing the receipt precedes stdout completion.

JSON `true`/`false` are invalid in integer `row_count`, column `channel`, `valid_rows` and `invalid_rows` metadata, including where their Python values compare equal to 0 or 1. The verifier rejects those substitutions through both its imported function and the saved-file CLI. Genuine integer 0/1 metadata, CSV bytes, fingerprints and other numeric parsing remain unchanged.

The `csv.newline: "CRLF"` declaration applies to every record separator. A fingerprint-consistent file with an interior bare LF/CR is rejected even if its final record still ends in CRLF. Python's `csv.reader(strict=True)` accepts those separators ([standard-library documentation](https://docs.python.org/3/library/csv.html#csv.Dialect.lineterminator)), so a quote-aware byte check follows the existing strict syntax parse. Quoted LF/CR/CRLF, doubled quotes, literal quotes inside unquoted fields, valid empty text and invalid blanks remain legal. Existing fingerprint, final-CRLF and syntax errors retain precedence; the caller's field limit is restored before the representation check.

```powershell
python validation/check_record_newlines.py NEW_CAPTURE_DIRECTORY
```

The capture directory must be new. Eight complete inputs and literal expected rows/errors are frozen in `record-newlines-cases.json`: two accepted controls, three interior-separator rejections, and three existing error controls. The receiver executes the saved-file verifier CLI eight times and imports it at both the caller's current field limit and 17 bytes (16 calls), retaining every input, exit, stdout/stderr and SHA-256 manifest. Its canonical CSV/receipt reuses the accepted UTF-16 producer output without rerunning that suite. Hand-written receipt/CSV controls check this verifier's declared representation; they do not assert correspondence to MDF samples, reparse MDF or demonstrate external adoption. Both CI jobs require this receiver.

The same `check_receipts.py` additionally saves one real two-column, one-row export with channel indices 0/1, then checks complete literal CSV bytes and standard CSV readback. It rejects 14 independent boolean substitutions across the seven integer metadata positions using both consumer entrypoints, checks clean CLI failure output, and retains two previously accepted numeric count spellings. Together with the original cases, the harness now checks nine receipt exports/18 data rows; no historical fixture is changed.

Round 11 also ran `check_gap_precision.py` against the changed exporter (16 scenarios/17 rows). The unchanged round-10 exact comparison code and 149 fixed vectors were preserved byte-for-byte; their successful numerical suite was not rerun.

## Catalogue-to-export selection (round 14)

`python validation/generate_catalog_fixture.py` regenerates the separate owned `analysis/catalog_fixture/` files from the existing unsorted MIT fixture. It changes channel names/units and origin while retaining records: two `速度🚲` signals occupy groups 0/1 with km/h and m/s units. A derivative changes only the first signal's conversion to unsupported CC99, demonstrating that inventory does not execute physical conversions. Historical fixture files stay unchanged; no vendor data or external dependency is used by the generator.

```powershell
moon test analysis/catalog_test.mbt --target js
moon test analysis/catalog_test.mbt --target wasm-gc
moon run example/catalog --target wasm-gc
moon build cmd/channels cmd/export --target js
python validation/check_catalog.py COMPILED_CHANNELS_JS COMPILED_EXPORT_JS NEW_CAPTURE_DIRECTORY
```

The capture directory must not exist. Standard Python invokes the actual Node commands, checks every ordered catalogue field against literal expectations, selects indices by duplicate name plus group/unit, and checks full CSV records. Four catalogue cases cover normal/unsupported-conversion/empty inventory and a Unicode filename with spaces. Five catalogue error paths emit stderr/nonzero and no JSON. Two selected exports/eight rows retain masks, units, order and exact origin; the script invokes `verify_export.py` on each saved CSV/receipt/source, checking actual hashes and schema. Normal MoonBit use/tests remain offline with committed bytes and do not require Python or asammdf.

The round-14 receipt separately records asammdf 8.8.28 metadata/group-aware lookup for both files, identical JS/Wasm-GC example data, and byte-for-byte CSV/receipt comparison with the pre-change compiled exporter. Its rebuilt binary identity changed after the additive analysis API; unchanged output is demonstrated by comparison, not inferred from its hash. No old gap/numerical/storage suite is rerun for this metadata-only addition.

## Selected source -> explicit endpoint grid (round 15)

`python validation/generate_summary_fixture.py` regenerates only the new owned `analysis/summary_fixture/` derivatives. They retain catalogue identities but add a physical CC7 enum and a CC1 master clock, plus ALL_INVALID and reversed-clock variants. Their emitted files match the pre-implementation operation-gap candidates byte-for-byte. Historical fixtures stay unchanged.

```powershell
moon test analysis/summary_test.mbt --target js
moon test analysis/summary_test.mbt --target wasm-gc
moon run example/summary --target wasm-gc
moon build cmd/summary cmd/channels cmd/export --target js
python validation/check_summary.py SUMMARY_JS CHANNELS_JS EXPORT_JS NEW_CAPTURE_DIRECTORY
```

Standard Python invokes the actual commands, uses catalogue group/unit to choose index 3, and checks six complete summary objects: calibrated enum, masked numeric, all-invalid, reversed, empty and signed zero. Eight error cases cover arguments, index parsing/range, unsupported physical conversion and missing/malformed files. The consumer explicitly chooses endpoint grids and Previous; two exports/three complete rows and both saved receipts pass the standalone byte verifier. Reversed order is reported, not sorted; empty endpoints remain null, and `-0` survives summary-to-export. The capture directory must not exist. Normal library/tests need no Python or external oracle.

The report's independent asammdf 8.8.28 readback agrees on physical values/clocks and the other masks. With CN flags 3, however, it returned false invalidation bits despite ALL_INVALID=1. That observed discrepancy and initial failure are retained; this one mask uses literal `[false,false]` validity from the explicit flag/project contract. No sample/vector was changed or omitted and no global oracle/SDK was patched. Five public tests per backend and actual summary output confirm the expected project behavior. This is not claimed as complete external-oracle agreement.

Actual old/new catalogue output and old/new selected CSV/receipt bytes were compared on the new calibrated source; their compiled identities are pinned separately. Unchanged earlier numerical/gap/storage/catalogue suites were not rerun.

## Explicit raster-file transport (round 16)

`example/raster/grid.json` is a shipped explicit irregular grid; `parse_raster_json` is pure on both targets. The new CLI form is `export FILE "@GRID.json" LABEL INDEX POLICY ...`, with UTF-8/optional BOM and an array of decimal clock strings. Original inline input remains available.

```powershell
moon test analysis/raster_test.mbt --target js
moon test analysis/raster_test.mbt --target wasm-gc
moon run example/raster --target wasm-gc
moon build cmd/export --target js
python validation/check_raster.py COMPILED_EXPORT_JS NEW_CAPTURE_DIRECTORY
```

The capture directory must not exist. Standard Python generates an explicit finite nonuniform 4096-point grid, checks every complete CSV row and every clock's binary64 bits, and invokes the saved-byte verifier on four outputs (4101 data rows): large grid, shipped four-point grid, UTF-8 BOM/Unicode-path -0 request, and empty grid. Seven invalid file/decode/shape/time inputs and a 4096-point/500-column CellLimit case must emit no CSV or receipt. No old numerical/source-summary suite or external oracle is needed.

The four parser tests per backend separately pin independent Python bits for -0, minimum subnormal, 0.29 and maximum finite, plus empty/BOM, shape and lexical/finite/order errors. The report retains the actual pre-change 77,212-UTF-16-unit Windows command failure (WinError 206 before Node starts). Both examples and a fresh old/new inline versus file-mode comparison agree byte-for-byte on CSV and receipt; the frozen-15 export cases are not rerun. The initial StringView path-ownership deprecation diagnostic is retained, resolved with the SDK-prescribed to_owned without changing inputs/expectations.


## Long legal CSV fields in saved-byte verification

The verifier uses the actual fingerprint-checked CSV byte length as a temporary parser field ceiling when Python's current limit is smaller, then restores the caller's setting in `finally`. This accepts long legal labels while retaining strict CSV parsing, schema checks, hashes, text/validity semantics and the existing MDF/alignment budgets. It does not use a global unbounded limit or introduce a new file format.

```powershell
python validation/check_long_fields.py COMPILED_EXPORT_JS NEW_CAPTURE_DIRECTORY
```

This standard-library regression invokes the actual exporter on three self-created TX/CC7 derivatives: ASCII labels at 131072 and 131073 characters, and a 131073-character Unicode label containing comma, quotes and newlines. Each has a long valid label plus a valid empty label (six complete rows in total). Complete CSV bytes must equal independently constructed csv.writer/literal expectations, and all three imported verifier calls must pass and restore the caller's limit, including a nondefault setting. One saved over-boundary case also passes the actual verifier CLI. An unterminated long quoted field with a matching test fingerprint still fails strict parsing through both import and CLI; the limit is restored and the CLI fails cleanly. The capture directory must not exist. The three source files/CSV/receipts and all actual command outputs are retained there; no historical fixture or dependency is modified.

## Indexed raw/physical channel inspection

```powershell
moon build cmd/inspect --target js
python validation/check_inspect.py COMPILED_CHANNELS_JS COMPILED_INSPECT_JS NEW_CAPTURE_DIRECTORY
```

This runnable standard-Python/Node consumer discovers two same-named channels by group/unit and passes their global indices to `inspect FILE --index INDEX`. A pinned owned fixture supplies 48 literal original DT bytes: four interleaved `<BdhB` records independently unpacked by Python `struct`. Complete expected JSON retains raw -3/6 and 42/-99 samples, their distinct clocks/units and the invalid sample. A separate aligned UInt64 read proves exact raw strings above 2^53 while physical values retain Double precision.

Checks also retain a converted master clock and source order, valid non-finite values with a separate mask, negative-zero/subnormal source cases with their legacy numeric spelling, zero/leading-zero/explicit-plus indices, unrelated unsupported conversion isolation, and legacy metadata/name/ambiguity behavior. One owned text-name derivative proves that two-argument `inspect FILE --index` still selects a literal channel named `--index`. Invalid/negative/overflow/out-of-range indices, malformed input and a selected unsupported conversion emit nonzero/stderr and no JSON. Existing missing/directory input failure semantics remain unchanged. The new capture directory contains actual command outputs, byte/value expectations, source hashes and the compiled inspector identity; original fixtures are never modified.

## Native record-window public API receiver

```powershell
moon test window_wbtest.mbt --target js
moon test window_wbtest.mbt --target wasm-gc
moon run example/window --target wasm-gc
moon build validation/window_receiver --target js
python validation/check_window.py files COMPILED_WINDOW_RECEIVER_JS NEW_CAPTURE_DIRECTORY
```

The portable example is an independent package importing the public root API. The separately compiled JS file receiver opens actual owned MDF files and calls window/old whole/raw API controls in separate invocations; it imports no private product decoder. Its test-only JSON view records the entire paired result, identity/origin, typed values and exact IEEE time/value bits, without changing any product CSV/receipt/CLI format. `check_window.py example EXAMPLE_JSON` independently checks the portable example on each backend.

The standard-Python file consumer pins original input bytes and independently unpacks aligned integers/floats and interleaved records with `struct`, literal expectations and simple conversion arithmetic. It covers first/middle/tail/full/empty, zero-record groups, native group positions, irregular/repeated/reversed and calibrated clocks, raw UInt64 above 2^53, invalid retained values, Number/Label/Data and identity nonfinite/signed-zero bits. New owned derivatives are written only into the new capture directory; original fixtures and old reference generators are untouched.

Known sample-level domain/UTF-8/invalid-master errors outside a requested window permit that window. Expanded windows and the unchanged relevant whole/raw APIs still fail, including an invalid selected value that must still be converted. Tests check metadata on empty windows, safe range overflow/error priority, absence of partial results, and full-file open failures for a late bad record ID plus existing sample/output/block budgets. The source loop is bounded to count records; no timing threshold or lazy-I/O/constant-total-memory claim is made. The focused API tests run on JS/Wasm-GC and also check independent result arrays and immutable-byte snapshots.
## Native-window saved-file handoff

After `moon build --target js`, run:

```sh
python validation/check_native_handoff.py _build/js/debug/build/zhaojun-coding-2/mdf4/cmd/native_handoff/native_handoff.js NEW_CAPTURE_DIRECTORY
```

Eight complete owned-byte/literal cases in `native-handoff-cases.json`
are independent of product output. The real compiled public-API command and the CLI
and imported independent saved-file receiver check complete results/receipts,
multiple native schedules, duplicates, overlap, empty requests/windows, invalid
values, exact UInt64 raw text, all scalar tags, Unicode, bytes and float bits.
The native real fixture is an exact copy of the earlier owned frozen artificial
window input (same core layout, explicit nonmonotonic clocks/negative zero and
Identity nonfinites); no external generator or new scientific reference is used.
Rehashed tampering checks ordering, metadata, scalar typing and repeated-record
consistency beyond fingerprints. A separate full literal comparison detects
semantically wrong but structurally self-consistent values; the receipt checker
does not claim arbitrary MDF recomputation. A scoped Node filesystem seam plus
V8 call coverage verifies one request/source read, one real public open and seven
read_window calls while an ephemeral source path changes after loading. This
proves use of one loaded image, not OS-level atomic acquisition.

For ordinary recipients, use `verify_native_handoff.py SOURCE REQUEST RESULT
RECEIPT`, as documented in [the command contract](../cmd/native_handoff/README.md).
The new native result/receipt versions are independent of aligned CSV/schema.
## Near-endpoint interpolation

The portable public consumer `example/interpolation` exercises CC4 conversion,
`Linear` and `Previous` using 14 complete frozen input/expected cases and 46
query points. Finite expectations use Python Fraction over the original binary64
inputs, followed by one rounding; masks/endpoints/outside rules and the unchanged
nonfinite/signed-zero controls are explicit complete literals. It covers collapsed
zero/one ratios, quantized subnormal fractions, cancellation, the smallest
representable output, true underflow, wide and subnormal time brackets.

```sh
moon run example/interpolation --target js > interpolation.json
python validation/check_interpolation.py example interpolation.json
python validation/check_interpolation.py files COMPILED_EXPORT_JS COMPILED_INSPECT_JS NEW_CAPTURE_DIRECTORY
```

The file receiver reads three owned MF4 byte fixtures derived from the unchanged
catalogue input. Two patch only group0 master clock bytes for a wide positive or
negative identity interval. The third appends an explicit identity CC4 to that
master and uses a small interior raw clock. Original ID/header/record layout,
UInt64 origin, groups and masks remain. Complete exported rows/schema/receipts
and complete indexed inspector output are checked against source-byte/literal
expectations, including a max-gap control. The existing saved CSV receiver
verifies actual output bytes/receipts. No external MDF or NumPy execution supplies
the oracle, and no old golden/reference generator is rerun.
## Finite numeric profiles

`example/profile` reads the public NumericProfile/NumericExtremum fields from
outside the owning analysis package, and separately consumes `to_json_string()`.
The independent checker compares all typed and JSON fields against frozen
original-byte/literal expectations. Point decimal strings are validated by exact
binary64 value/sign bits, rather than a single assumed decimal spelling.

```sh
moon run example/profile --target js > profile.json
python validation/check_profile.py example profile.json
python validation/check_profile.py files COMPILED_SUMMARY_JS NEW_CAPTURE_DIRECTORY
```

Twelve full successful profiles cover42 source-record occurrences, including
invalid apparent peaks, valid/invalid nonfinites, signed-zero first ties, empty and
all-invalid/all-nonfinite inputs, reverse clock ties, duplicate names/groups and
UInt64 physical rounding. Seven real profile errors include labels/data even
when invalid or numeric-looking, missing/negative global indices and unsupported
selected conversion. An unsupported unselected sibling remains readable.
The actual file receiver also checks the full legacy summary and four argument/
I/O rejections through24 direct Node calls, with empty stdout on every failure.

Four committed MIT derivatives in `analysis/profile_fixture` change explicit
owned DT bytes only: signed-zero first value/time, all-invalid numeric masks,
reverse-clock equal-value ties and all-nonfinite values. The portable fixture
package also embeds the unchanged owned native-real input. All original MF4
files, reference outputs and old tests remain; no external generator supplies
the expected profile, and no third-party MDF runtime is needed.

## Clock coordinates

The executable [clock guide](../docs/clock-coordinates.md) fixes the incorrect
assumption that every converted master coordinate is already in seconds.
`example/clock` reads full public metadata/raw/native Series on JS/Wasm-GC and
explicitly normalizes only the two known producer contracts. Its three complete
outputs retain UInt64 maximum origin, group/index identity, source units, masks
and raw/physical values. Both normalized sources give the same Previous/Linear
results; an empty-unit source remains unconverted with its invalid value present.

Initial clock expectations were frozen before implementation/product execution.
The first comparison exposed two incorrect raw-value expectations in the
unknown-unit control; direct signed16 decoding of original bytes `fdff/0600`
established `-3/6`, replacing the assumed `1/4`. The original freeze, failed
output and executed source copy remain in the R11 report; committed
`clock-cases.json` contains the corrected independent expectations. No input,
example implementation or clock/normalization expectation changed for that fix.
The two new legal MIT byte derivatives in `analysis/clock_fixture`
append only group1 master unit/CC1 blocks to the unchanged own catalogue. Raw
clocks 0.25/0.75 become 750/1250 ms or 0.75/1.25 s through explicit coefficients;
the original record bytes and previous legal/failure fixtures remain intact.
No product decoder or third-party runtime generated expected results.

```sh
moon run example/clock --target js > clock.json
python validation/check_clock.py example clock.json
python validation/check_clock.py files COMPILED_INSPECT_JS COMPILED_EXPORT_JS NEW_CAPTURE_DIRECTORY
```

The file check retains seven real Node calls: four complete master/signal JSON
inspections and three full CSVs/nine data rows. Native ms numbers remain unchanged
under the old `time_s` header; a seconds raster on that ms source is wholly
outside-domain. This documents the current contract and does not normalize or
rename old outputs. Source inputs are byte-pinned before/after execution, and
complete argv/stdout/stderr plus compiled/input/output hashes are captured.
