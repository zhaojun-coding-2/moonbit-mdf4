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

The owned modules are `zhaojun-coding-2/mdf4` and `zhaojun-coding-2/mdf4-csv-consumer-example`. In each target job, the existing native-check/native-example/independent-examples gates compile and execute the separate public-package consumer, checking its full CSV/schema/typed views against independent expectations. The `MDF4 verified namespace consumer` notice and `publicConsumerNamespace` manifest bind the actual declared modules, consumer compiled path/SHA-256 and complete output SHA-256. Executables are resolved within the declared module's build directory, so retained artifacts from a prior namespace are not selected by a global filename search. This is executable public-import verification, without a string-replacement-only test or package publication.
## Native-window handoff gate

The JS job additionally runs the real compiled `cmd/native_handoff` through
`validation/check_native_handoff.py`. This is necessary for the new Node-only
file workflow: complete frozen literal results and receipts, the independent
saved-file receiver, request/source/group/range/metadata/resource/I/O failures,
rehashed structural tampering, and a one-loaded-image filesystem/V8 seam.
The `MDF4 verified native handoff` notice binds the actual commit, compiled JS,
full literal oracle, receiver and saved consumer manifest with SHA-256 and case
counts. The underlying library remains covered on both JS and Wasm-GC by all
existing necessary gates. No prior gate or accepted oracle is removed or relaxed.
The uploaded manifest and annotations are evidence metadata; they do not by
themselves prove that a separately downloaded CI binary payload was read back.
## Near-endpoint interpolation gate

Both required jobs compile/run `example/interpolation` and compare its complete
CC4/Linear/Previous/mask output using `validation/check_interpolation.py example`.
The JS job also requires actual exporter/inspector consumption of three frozen
MF4 inputs, complete CSV/schema/receipt and source-byte checks, a max-gap control
and saved-file receipt verification. `MDF4 verified interpolation precision`
binds target/head, actual portable compiled/output SHA-256, the full independent
oracle, 14 cases/46 points, and the JS file-consumer manifest (not applicable to
the portable-only Wasm-GC job). Every previous required gate remains in place.
## Finite numeric profile gate

Both required targets run the actual portable `example/profile` and compare all
typed/wire fields via `check_profile.py example`:12 successful profiles,7 errors,
42 logical source-record occurrences. The JS job additionally runs
`check_profile.py files` against the real compiled summary:24 Node invocations,
including a full legacy summary control and four entry/I/O failures.
`MDF4 verified numeric profile` binds exact target/head, actual compiled and output
hashes, complete independent oracle and counts, and the JS file manifest (not
applicable for portable-only Wasm-GC). Prior necessary gates remain unchanged.
