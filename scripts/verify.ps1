$ErrorActionPreference = 'Stop'
Push-Location (Join-Path $PSScriptRoot '..')
try {
    foreach ($target in @('js', 'wasm-gc')) {
        & moon check --target $target
        if ($LASTEXITCODE -ne 0) { throw "moon check $target failed" }
        & moon build --target $target
        if ($LASTEXITCODE -ne 0) { throw "moon build $target failed" }
        & moon test -p zhaojun-coding-2/mdf4 --target $target
        if ($LASTEXITCODE -ne 0) { throw "moon test $target failed" }
    }
    & moon run example --target wasm-gc
    if ($LASTEXITCODE -ne 0) { throw 'example failed' }
    & moon run cmd/inspect --target js -- testdata/core-c2.mf4 linear
    if ($LASTEXITCODE -ne 0) { throw 'CLI consumer failed' }
} finally {
    Pop-Location
}
