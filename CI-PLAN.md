# Required verification and retained evidence

The existing [CI workflow](.github/workflows/ci.yml) runs `verify-js` and `verify-wasm-gc` on Ubuntu 24.04 with checksum-pinned private MoonBit SDK/dependencies, Node 24.11.0 and Python 3.12. `.ci/run_checks.py --target TARGET --results NEW_DIRECTORY` executes real formatting, compiler, build and full tests, public examples and independent consumers. Both jobs must succeed on the final commit; a local result or an earlier commit's green run is insufficient. No fixture generator is required by these gates.

The saved-artifact representation gate is `consumer-record-newlines`, required in both jobs:

```powershell
python validation/check_record_newlines.py NEW_CAPTURE_DIRECTORY
```

It uses the eight complete, frozen inputs in `validation/record-newlines-cases.json` and the exact committed source fingerprint. Expected complete fields and errors were specified before the receiver fix. The gate checks two accepted controls, three falsely accepted interior record separators, three existing error paths, eight actual CLI exits/outputs and 16 imported calls with field-limit restoration. Legal quoted LF/CR/CRLF, doubled quotes and an unquoted literal quote are compatibility controls. It does not regenerate the accepted producer fixture or infer new MDF semantics.

For this Python verifier change, the relevant local pass also runs the existing `check_receipts.py COMPILED_EXPORT_JS NEW_DIRECTORY` and `check_long_fields.py COMPILED_EXPORT_JS NEW_DIRECTORY` against the unchanged exporter. This covers saved receipts/schema, old error/flag/integer metadata contracts, long legal text and strict parsing. Local validation need not repeat unchanged scientific collections; the full committed CI gates remain required.

Each job retains raw command stdout/stderr and exit/argv/cwd in `commands.json`, input/output manifests, and `source-and-verification.json` with actual source and compiled artifact identities. The new receiver retains each saved CSV/receipt, CLI output and a `record-newlines/manifest.json`. A `MDF4 verified record newlines` notice binds target, commit, verifier/receiver/fixture SHA-256, manifest SHA-256 and case/import counts. Existing source, exporter/inspector, public query/UTF-16 and file gates remain in place.

The always-run upload step retains the job's evidence under `mdf4-TARGET-COMMIT` for 14 days. Job annotations and artifact-list metadata establish only what was reported by that run. Independently downloaded binary bytes require separate readback; metadata is not a binary download. Self-written receivers and passing CI do not establish outside product adoption, contest acceptance, MDF conformance or authenticity of unsigned receipts. Receipts validate source/CSV fingerprints and CSV/schema consistency without reparsing MDF.
