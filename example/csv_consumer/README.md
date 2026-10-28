# Optional native CSV consumer

This standalone example connects the existing MDF4 `to_csv()` / `schema_json()` output to [NyaCSV](https://github.com/moonbit-community/NyaCSV). It prints a JSON report from self-created fixtures. A valid cell is `{ "kind": "label", "text": "" }`, for example; an invalid cell is JSON `null`. Number, Label and Data retain their schema kind while their CSV text stays unchanged. This avoids guessing that Label("1") is a number or that a valid empty label is missing. NaN/Infinity are tagged text rather than JSON numbers; origin and clock text, including `-0`, are never numerically coerced.

## Run from a local source checkout

Requirements: the root project's MoonBit/Node dependencies, plus Git. This directory is a separate Moon module: running the root library does not resolve NyaCSV. From the project root:

```powershell
Set-Location example/csv_consumer
git clone --no-checkout https://github.com/moonbit-community/NyaCSV.git .deps/NyaCSV
git -C .deps/NyaCSV checkout --detach 19ab9ca861f13a0663dc6e168b764507fa0e76ba
Copy-Item moon.work.example moon.work
moon update
moon run . --target js
moon run . --target wasm-gc
```

Create the checkout/workspace once; subsequent runs start at `moon run`. `DEPENDENCY.json` records the exact upstream sources used. The workspace template resolves MDF4 to `../..` and NyaCSV to the local pinned checkout. Dependency caches, `.deps/`, `moon.work` and build products are excluded from source delivery. No SDK binary or standard-library modification is needed.

If the root checkout already uses a `moon.work` with local dependency overrides, add those same dependency directories to this example's workspace with `moon work use PATH` before `moon update`. The recorded validation used the root's existing gmlewis workspace members; this round does not revalidate a fresh registry-only installation of those historical dependency versions.

The pin declares upstream version **0.3.4**. This does not claim a Mooncakes 0.3.4 release. The registry's 0.3.3 artifact failed with the validation SDK (compiler 0.10.17): it has an obsolete `moon.mod.json` and obsolete Buffer calls. The pinned upstream commit already contains the corresponding compatibility changes; this example does not patch the dependency. Retain upstream Apache-2.0 notices when distributing a build that includes it.

## What the report demonstrates

- Quoted comma, escaped quotes, an embedded newline, a non-BMP header (`state 🚦`), and valid empty text versus invalid blank.
- Number("1"), Label("1") and Data hex remain distinct through CSV plus schema, including the exact UInt64 origin string.
- Valid NaN/Infinity remain text; the fixture's invalid negative-infinity sample remains null. An explicit `-0` clock stays `"-0"`.
- All-invalid columns retain an empty observed-kind list and null cells, without a guessed type.
- Five damaged/unsupported views are rejected: wrong schema version, wrong header, omitted rows, invalid validity text and an ambiguous column-kind union.

`consume` is a small recipe for this producer's homogeneous-kind columns, not a new public MDF API. A column-wide union cannot recover each field's original kind, so the example rejects it. The parsed header/rows are included to make the external-parser boundary inspectable. The example keeps string values; converting them to numeric arrays or a DataFrame needs the application's own policy. It neither authenticates the CSV/schema pair nor reconstructs MDF. For saved-file fingerprints and receipt checking use the root `validation/verify_export.py`; this recipe does not replace that verifier or validate arbitrary untrusted CSV.
