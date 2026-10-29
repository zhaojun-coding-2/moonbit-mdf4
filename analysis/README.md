# MDF analysis table

Import `zhaojun-coding/mdf4/analysis` and the root package. The library and `example/table` run on JS/Wasm-GC; `cmd/export` adapts Node file I/O.

## Channel discovery

`channel_catalog_json(file : @mdf.MdfFile) -> String` serializes the opened file's existing channel metadata on JS/Wasm-GC. `cmd/channels FILE.mf4` provides the Node file adapter and `example/catalog` shows the owned duplicate-name/unit fixture. No physical channel extraction or conversion is performed by this formatter. The Node command first uses the normal in-memory `open`, including record/data validation and existing limits.

The JSON object has `catalogue_version: "mdf4.analysis.channels/1"`, `file_version`, exact decimal-string `start_ns`, and `channels`. Each ordered row has `index`, `group`, `name`, `unit`, `channel_kind`, `sync_type`, `data_type`, and `bit_count`. `index` is the zero-based global position used by `MdfFile.read_channel`, `ChannelRequest.channel` and export; `group` is the root API's channel-group index. Preserve the whole row when names repeat. The three type/kind/sync fields are original numeric MDF metadata codes; bit_count is the raw storage width. They do not infer a physical Value kind or select an interpolation policy. Units retain the existing root text representation, without new XML/unit processing.

All channels remain in traversal order, including time masters and same-named signals. Empty files return `channels: []` with file metadata. An unsupported physical conversion can still be listed; actual selected reads keep their existing errors. Catalogue presence is not a readability certificate. It contains no raster, sample count, guessed time range or source digest; the existing aligned schema/receipt describes and fingerprints a later chosen export.

The new Node executable accepts exactly one file argument; missing/extra/unreadable/malformed input returns nonzero, reports stderr and emits no catalogue JSON. Existing inspect/export syntax is unchanged. The root `channels()` typed API remains available; the catalogue is its versioned JSON adapter for downstream selection.

## Selected source summary

`channel_summary_json(file, index) -> Result[String, @mdf.MdfError]` physically reads one catalogue/global index through the existing root API. `cmd/summary FILE INDEX` is the Node adapter; `example/summary` runs on JS/Wasm-GC. A raw numeric storage code can convert to Label values, and the master conversion can shift its source clocks, so catalogue raw metadata alone does not determine a raster or interpolation policy.

The JSON version is `summary_version: "mdf4.analysis.channel-summary/1"`. It contains `file_version`, exact decimal-string `start_ns`, `index`, `group`, `name`, `unit`, `sample_count`, `valid_samples`, `invalid_samples`, `value_kinds`, `first_time`, `last_time`, and `strict_time_order`. Counts refer to original source samples before alignment. Kinds are distinct number/label/data variants across **all** converted samples, in canonical order, including invalid samples. This differs from aligned schema's valid-only `valid_value_kinds`; empty sources report `[]` without inferring their storage/converted type.

Endpoints are round-trip strings of the existing Double clock, including `-0`, or explicit JSON null for empty sources. They preserve the first/last source positions, without re-zeroing or adding the HD origin. Strict order requires every adjacent timestamp to increase; empty/single sources return true. When false, endpoints need not be extrema and the source remains unsorted in the summary. The summary neither repairs clocks nor relaxes the existing alignment checks.

The compact result does not include every timestamp/sample, infer a cadence or choose a policy/grid. Use root `read_channel` for complete arrays. Selected bad indices, unsupported conversions and other read failures keep the original MdfError. Catalogue metadata remains available independently of physical conversion. Normal file opening/extraction remains in-memory with existing limits; a compact result is not a streaming or partial read. Unit/XML and physical Double precision follow the root contract.

## Alignment

`parse_raster_json(text) -> Result[Array[Double], AnalysisError]` reads an explicit JSON array of decimal clock strings, optionally preceded by one BOM. It uses the installed core JSON and decimal parser; points are the actual binary64 results, including negative zero. Every point must be finite and strictly increase in its supplied order. Distinct decimal strings that round to the same Double are duplicate coordinates and return `InvalidRequest`. Empty arrays are valid. Non-array roots, non-string items, malformed JSON/numbers and non-finite/non-increasing points return the existing InvalidRequest variant. No cadence, sorting, deduplication or source lookup occurs; the caller/align still controls budgets and policies.

The Node exporter accepts `"@PATH"` instead of the comma-separated RASTER argument to load that UTF-8 document (optional BOM). The shipped `example/raster/grid.json` lists four uneven points and `example/raster` demonstrates the pure parser and alignment on both targets. The document contains only time points; it is not a general argument-response file or saved analysis plan. Existing comma/empty rasters, labels and tail options remain available. Full file/JSON/array materialization is in-memory; removing argument-size pressure does not remove the table's logical-cell limit. The unchanged receipt fingerprints interpreted CSV times rather than raw JSON spelling/bytes.

`align(file, requests, raster, max_cells=1000000) -> Result[AlignedTable, AnalysisError]` accepts an array of `ChannelRequest { channel, label, policy }`. Channel is the zero-based root channel index; label is a nonempty unique output alias; policy is root `Previous` or numeric `Linear`. Select by index when names repeat. The first per-channel failure returns `Channel(label,index,MdfError)`; request/schema errors return `InvalidRequest`; the logical-cell budget returns `CellLimit`. The existing root API is unchanged.

An opaque table supplies `start_ns()`, `row_count()`, `column_count()`, `timestamps()`, `columns()`, `max_gap()`, `to_csv()` and `schema_json()`. `AlignedColumn` snapshots include source channel/name/unit, output label, policy, typed Value arrays and matching validity arrays. Snapshot arrays are detached; mutating them cannot alter the table. Invalid values remain inspectable in the typed snapshot, matching root Series semantics.

The raster is copied, finite and strictly increasing. At least one column is required. Empty grids are accepted and retain schema. Max cells is checked as rows <= budget/columns, before reading/converting channels, avoiding multiplication overflow; it bounds logical value cells rather than bytes. Output remains an in-memory table/string.

## Saved analysis query input

`align_query(file, query_json, max_cells=1000000) -> Result[AlignedTable, AnalysisError]` executes the complete input form shown in `example/query/request.json`: exactly `query_version` (`mdf4.analysis.query/1`), `raster`, `columns` and `max_gap_seconds`. The document is JSON text with one optional leading BOM. Each ordered column has exactly `channel`, `label`, `policy`: channel is a nonempty ASCII decimal string in nonnegative Int32 range, including leading zeros; label is a string; policy is `previous`/`linear`. Raster parsing delegates to `parse_raster_json`. Gap is explicit null or a decimal string using the existing finite nonnegative cap rules. Core JSON duplicate-key behavior is retained; duplicate detection is not advertised.

The operation only orchestrates existing alignment. Missing/unknown fields, wrong types and lexical errors return `InvalidRequest`; old label/header/channel/clock/interpolation errors and `CellLimit` propagate in the existing variants. Query syntax/root/fields/version precede raster parsing, ordered column parsing, gap parsing and then original alignment checks. It preserves fresh table snapshots, exact origin, source indices/order/units, invalid values and every requested row. It adds no paths/includes, batch mode, automatic channel matching, generated grid or output schema; `max_cells` stays a separate caller resource policy.

The exact file adapter is `export FILE --query QUERY_FILE [--receipt NEW_PATH]`; the old RASTER forms and column labels named `--query` remain available. Query I/O/UTF-8 precedes normal source open, which precedes semantic query errors; old exclusive receipt creation precedes CSV emission. Existing full-file open/physical-read costs and budgets stay in place. The receipt still fingerprints source and interpreted CSV rather than raw query bytes. `example/query` is a separately compiled public receiver on both targets; `validation/check_query.py` checks the complete public/file artifacts against original bytes and hand-written cells.

CSV schema:

| Field | Representation |
|---|---|
| start_ns | Exact UInt64 decimal origin repeated on each row |
| time_s | Original requested relative time; no re-zeroing |
| label [unit] | Number text (including -0), enum/string label, or lowercase 0x byte hex; unit brackets omitted if empty |
| value header + __valid | true or false; invalid/outside-domain value field is blank |

Every field is quoted with double quotes; internal quotes are doubled; records end CRLF. Valid empty strings differ from missing through the validity field. Valid NaN/Infinity are explicit text because record validity and mathematical finiteness are separate. Generated headers must not collide with one another or start_ns/time_s. CSV does not preserve Value tags as a reversible MDF encoding and does not neutralize spreadsheet formulas.

Run the root README's two-channel export or `moon run example/table --target wasm-gc`. The latter emits a JSON report containing the CSV for easy machine comparison. `python validation/check_analysis.py PATH_TO_COMPILED_EXPORT_JS` independently checks full CSV records and CLI errors using standard Python only; normal library use/tests do not require Python. Synthetic fixture provenance is in `analysis/fixture/manifest.json` and regeneration is `python validation/generate_analysis_fixtures.py`.


## Gap-limited alignment

`align_with_gap(file, requests, raster, max_gap=seconds, max_cells=1000000)` is a separate opt-in entry point. The existing `align` signature is unchanged. The chosen finite nonnegative limit applies across the selected table: Previous compares query time minus held observation time; Linear interior points compare the full source bracket. Equality passes. This compares the exact difference of the supplied binary64 clock endpoints to the supplied binary64 limit. A rounded subtraction equal to the cap is resolved by its error-free residual, so a just-over-cap distance is not accepted as equal. Exact observed times keep original validity even beside a long interval. Existing invalid bits/out-of-domain samples remain invalid; computed typed values and all requested rows are retained. A zero limit permits exact observations only. `table.max_gap()` returns Some(seconds), or None when built with unrestricted align.

Node export accepts trailing `--max-gap SECONDS`; `example/gaps` compares both operations on a fixed nine-row grid and runs on JS/Wasm-GC. No global/per-column defaults are changed. Per-column gap thresholds are outside this increment; interpolation policies still differ per column.

CSV retains negative-zero signs explicitly for both numeric values and requested time fields. `python validation/check_gaps.py PATH_TO_COMPILED_EXPORT_JS` checks complete gap-limited CSV rows and numeric bits with Python's csv/struct modules. The extra owned fixture files are listed in `analysis/fixture/gap-manifest.json`; regenerate them with `python validation/generate_gap_fixtures.py` after the original analysis fixtures exist.


`validation/check_gap_precision.py COMPILED_EXPORT_JS [CAPTURE_DIRECTORY]` exercises original over-limit counterexamples, exact/neighboring limits, tiny spans, exact observations and unrestricted mode using exact Python Fraction comparisons. The optional capture directory saves complete actual CSV outputs. `python validation/generate_gap_precision.py` reproduces the separate owned precision_fixture files. The toolchain-specific decimal-literal diagnostic and bit-exact fixture correction are report-only; every original vector remains in the tests.

## Schema and optional review receipt

`AlignedTable::schema_json() -> String` returns standard JSON on JS/Wasm-GC. It adds no file I/O. A self-created MDF with numeric `1,2` and enum labels `"1","2"` demonstrates why this is useful: selecting either with the same alias produces identical CSV bytes, while the schema retains the distinct channel index and observed Value kind.

| Schema field | Contract |
|---|---|
| schema_version | `mdf4.analysis.schema/1` |
| start_ns | Exact UInt64 decimal string |
| row_count | Requested raster length |
| origin_header / time_header | `start_ns` / `time_s` |
| max_gap_seconds | Decimal string, including `-0`, or explicit JSON null for unrestricted alignment |
| first_time / last_time | Original raster endpoint strings, including `-0`, or explicit JSON null for an empty grid |
| columns | Ordered selected columns, including metadata and validity counts |

Each column contains `channel`, `label`, `source_name`, `unit`, `interpolation` (`previous` or `linear`), `value_header`, `validity_header`, `valid_rows`, `invalid_rows`, and `valid_value_kinds`. The last field is the distinct kinds actually present in valid emitted cells, in canonical `number,label,data` order. It excludes invalid/outside-domain placeholders; empty/all-invalid columns use `[]`. Valid NaN/Infinity are still `number`. These are observations about this result, not a declaration of the source channel's storage type. The CSV time column retains the full raster; the schema stores only its endpoints and count.

`cmd/export ... [--max-gap SECONDS] [--receipt NEW_PATH]` optionally writes a JSON sidecar using Node built-in crypto/fs. Both option orders are accepted. The receipt has `receipt_version: "mdf4.analysis.receipt/1"`, `source: {sha256, bytes}`, `csv: {sha256, bytes, encoding: "UTF-8", newline: "CRLF"}`, and `table` containing the schema object. Fingerprints cover the same loaded source bytes passed to `open` and the exact UTF-8 CSV string passed to stdout; no source path or clock time is included.

The receipt uses exclusive file creation: an existing path or creation failure causes a nonzero exit before CSV emission. The caller controls stdout redirection and must verify the saved CSV; receipt creation precedes stdout and does not prove that redirection completed. The normal exporter creates no receipt and retains its old CSV bytes. This MDF-specific format supports review and consistency checks; it is neither a signed artifact, generic CSVW/Frictionless conformance claim, nor a reversible MDF encoding. `example/receipt` emits CSV plus schema JSON on both backends; only the Node CLI adds source/CSV fingerprints. Reproduction and an optional standard-Python verifier are documented in `validation/README.md`.
