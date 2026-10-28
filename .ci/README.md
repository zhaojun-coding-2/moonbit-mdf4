# Reproducible verification

CI uses ordinary Ubuntu 24.04 hosted runners, separate JS/Wasm-GC jobs and a 20-minute timeout. The MoonBit toolchain/core archives, module archive versions/hashes and upstream NyaCSV commit are pinned in this directory. GitHub's official checkout/setup/upload actions are pinned by commit. The SDK download interface and standard-library bundle commands follow the official MoonBit distribution/installer; no floating installer is executed and no global SDK/profile is edited.

`bootstrap.py` downloads only public fixed sources and writes the explicitly selected private SDK/dependency directories plus ignored `moon.work` files. On Linux it also applies the official Unix installer's executable permissions and `moonx` link inside that private SDK. The root module dependency declarations and the separate native-consumer module stay unchanged. No registry index or login is needed. NyaCSV's older source manifest recorded a Windows CRLF checkout: extraction materializes LF/CRLF differences only when the exact recorded per-file SHA-256 is reproduced; all other mismatches fail. This preserves the fixed dependency source bytes, not a patched parser.

`run_checks.py` runs actual format/check/build/test commands without a root-package-only test filter. Both targets run real raster/receipt/native examples plus a public-API native-window example, with independent Python checks. JS additionally runs the layout, gap, exact-duration, receipt, catalogue, source-summary, raster-file, long-field, indexed-inspection and public native-window file consumer scripts. Unexpected failures exit nonzero and emit a bounded GitHub annotation for diagnosis; there is no continue-on-error or success substitution. Evidence artifacts contain command receipts, generated owned samples/outputs and source identities, without SDKs or dependency sources. Successful JS consumers also report the compiled exporter, inspector and window-receiver hashes.

For a private local setup, use a project-owned directory (PowerShell example):

```powershell
python .ci/bootstrap.py sdk --sdk-dir .ci-cache/toolchain --cache-dir .ci-cache/downloads
$env:MOON_HOME = (Resolve-Path .ci-cache/toolchain).Path
$env:PATH = "$env:MOON_HOME/bin;$env:PATH"
moon -C "$env:MOON_HOME/lib/core" bundle --warn-list -a --all
moon -C "$env:MOON_HOME/lib/core" bundle --warn-list -a --target wasm-gc --quiet
python .ci/bootstrap.py deps --deps-dir .ci-cache/dependencies --cache-dir .ci-cache/downloads --include-native
python .ci/run_checks.py --target js --results .ci-cache/results-js
python .ci/run_checks.py --target wasm-gc --results .ci-cache/results-wasm-gc
```

Each results directory must be new. Dependency licenses remain those of their publishers, as documented in THIRD_PARTY.md. The core uses no Python runtime; these scripts are verification/setup tooling. Actual CI conclusions are available from the repository Actions runs; the presence of this workflow alone is not a passing run.
