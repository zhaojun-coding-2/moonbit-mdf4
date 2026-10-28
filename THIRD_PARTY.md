# Sources and data

## Product and references

- The MoonBit reader, AST, conversion/alignment code and synthetic fixture generator work are MIT under the root LICENSE. Author identity is `zhaojun-coding`; dependency authors are not the applicant.
- Runtime dependency `gmlewis/zlib@0.21.17` uses `gmlewis/flate@0.36.17`, `gmlewis/hash@0.21.2`, `gmlewis/io@0.23.20`; io in turn uses `gmlewis/base64@0.16.14`. Published packages carry Apache-2.0. zlib/flate sources document Go BSD-derived origins. Preserve their license/origin notices when distributing bundled builds. Dependency source is separate from the MoonBit core.
- Optional standalone `example/csv_consumer` uses `moonbit-community/NyaCSV` from upstream commit `19ab9ca861f13a0663dc6e168b764507fa0e76ba` (source declares 0.3.4), Apache-2.0. This is a source pin, not a claim of a Mooncakes release. It is separate from the root dependency graph. No NyaCSV source is vendored or relabeled MIT; the example's `DEPENDENCY.json` records exact source/license hashes. Preserve the upstream Apache-2.0 license and origin notices if distributing a linked build. The published 0.3.3 package was evaluated but is incompatible with this validation SDK; no local dependency patch is shipped.
- Layout/behavior reference: [ihedvall/mdflib](https://github.com/ihedvall/mdflib/tree/69adcbc5c221357c4d226a74758af21edb85b139), MIT, Copyright 2022 Ingemar Hedvall. The reviewed CC/CG/CN/DG/DL/HL/HD read layouts and DZ behavior informed this implementation; code is organized and written for MoonBit rather than binding C++. The reference MIT notice is retained under `licenses/`.
- [ASAM MDF public overview](https://www.asam.net/standards/detail/mdf/wiki/) and release presentations provide terminology and feature context. The complete licensed ASAM base/associated standards were not obtained; no specification PDF/schema/example package is redistributed or relabeled MIT.
- `asammdf 8.8.28`, LGPLv3+, is an external Python-process generator/reader oracle, not a runtime dependency or copied product implementation. This chat inspected asammdf code during an earlier review, so this work does not claim never-exposed clean-room status. This implementation phase used its public API and license/distribution metadata only.

## Data separation

`testdata/` and embedded fixture byte constants are artificial files produced for this project, using self-specified numeric samples and asammdf or a small layout writer. They are distributable with this project under MIT. No vendor calibration or road recording is embedded. Their source identities and regeneration process are under `validation/`.

The local real-input check used CSS Electronics' official example recording:

- Repository commit: `f7932bacb2969dec591508d15f89e8a898ca99c6`.
- Path: `examples/data-processing/LOG/FCBF0606/00003482/00000001-60B621D9.MF4` in [api-examples](https://github.com/CSS-Electronics/api-examples).
- Original SHA256: `2c795d0d5beb8fe250f0080db9ee29d17d31b7f2e5e13c06f865e2f702bf5de2`; 72,820 bytes; identifier `UnFinMF 4.11`.
- The publisher's [tool documentation](https://canlogger.csselectronics.com/canedge-getting-started/ce2/log-file-tools/) invites downloading samples to test tools. This was the basis for local interoperability evaluation; it is not a finding that all CSS data is freely redistributable.
- CC-BY4 was not verified. The public v2.1 MF4 archive was inspected and had no README/license text; the API repository's root MIT text is not used to infer licensing of external archives or DBC files. No CSS file is distributed with this project.
- The test additionally used `asammdf 8.8.28 MDF.save(compression=2)` to produce a separately hashed finalized file in the private execution directory. It is explicitly a preprocessed input, not a claim this product repairs arbitrary UnFinMF files.

No DBC decoder/database is needed by the core or the checked-in examples. If a future consumer adds road data, DBC/ARXML or ASAM materials, establish each source's authorization and redistribution terms separately.


## Exact duration comparison

The max-gap predicate uses standard error-free TwoDiff residual arithmetic. Its primary mathematical/software reference is Jonathan R. Shewchuk's [robust predicates page](https://www.cs.cmu.edu/~quake/robust.html) and the `Two_Diff_Tail` arithmetic in the author's [predicates.c](https://www.cs.cmu.edu/afs/cs/project/quake/public/code/predicates.c). The author explicitly places that code in the public domain. This project implements the finite binary64 comparison in MoonBit; no C runtime or new dependency is included. The supported JS/Wasm-GC verification uses binary64 operations, not extended-precision native registers.
