# Clock coordinates before resampling or export

`read_channel(index).timestamps` contains the selected group's time master's
**physical numeric coordinates**. The reader decodes the raw master and applies
its MDF conversion. It does not inspect the unit text and convert milliseconds
to seconds, add the HD origin, infer a sample rate or synchronize different
groups. `kind=2, sync=1` identifies a time master; it does not establish a numeric
scale. An empty master unit is unknown, not evidence of seconds.

This matters before choosing a raster. A valid source master with raw values
`0.25,0.75`, conversion `1000*x+500` and stored unit `ms` produces timestamps
`750,1250`. Asking for the seconds raster `0.75,1,1.25` directly is outside that
source domain. It produces invalid aligned cells rather than converting units.
The same acquisition represented by conversion `x+0.5` and unit `s` produces
`0.75,1.25` directly. The exact UInt64 `start_ns` remains separate in both files.

## Inspect the source clock contract

1. Select a global channel index from `channels()`/the catalogue. Names may repeat.
2. Find the unique same-group channel with `kind=2, sync=1`, then inspect its
   stored unit and raw/physical values. A signal's own unit describes its values,
   not its timestamps. Ordinary unit text is preserved; XML/compound units are
   not interpreted by this reader.
3. Obtain the producer's scale, zero/reference and relation to the HD origin.
   A unit label alone does not establish the offset or synchronization between
   groups. Keep `start_ns` as UInt64/string rather than a floating-point number.
4. Either work entirely in the confirmed native coordinate system, or explicitly
   normalize a copied Series and the caller's raster into the same coordinates.
   Apply interpolation only after that decision. Retain source values and masks.

For the **known owned millisecond fixture only**, the producer contract specifies
division by 1000 with no further offset. This is application code using the
existing public Series and resample APIs, not a new unit-conversion API:

```moonbit
let source = file.read_channel(3).unwrap()
let seconds : @mdf.Series = {
  ..source,
  timestamps: source.timestamps.map(t => t / 1000.0),
}
let raster = [0.75, 1.0, 1.25, 1.5]
let sampled = @mdf.resample(seconds, raster, @mdf.Linear).unwrap()
```

The owned signal has values `42,-99` and both samples valid. After normalization,
Linear produces `42,-28.5,-99` at the first three raster points; Previous produces
`42,42,-99`. The final 1.5 point is outside the domain and remains invalid with the
existing NaN placeholder. Neither interpolation extrapolates. Real callers must
also handle Result errors, invalid samples, nonfinite/unsorted clocks and the
precision consequences of their chosen normalization. No arbitrary normalization
is offered for the example with an empty master unit; its invalid physical value
remains present and its caller must supply a clock contract.

## Existing aligned CSV and gap names

The legacy aligned table/CLI uses `time_s`, `max_gap_seconds` and `--max-gap`.
Those **names do not perform or validate unit conversion**. The implementation
compares the provided raster and gap directly with the source's physical numeric
timestamps. A gap cap of 0.25 on the millisecond source is0.25 native milliseconds,
not 250 milliseconds. A receipt fingerprints the actual bytes and schema; it
does not certify a clock's unit or synchronization.

Use the existing seconds-labelled export as seconds only after confirming that
every selected group's physical coordinates already share the intended seconds
scale/reference. The file exporter does not accept a caller-normalized Series.
For a non-second/unknown source, use the native reader/window handoff with its
source master metadata, or normalize and resample through your own consumer as
above and choose an output representation that accurately records that decision.
Changing a CSV header alone does not convert coordinates. Do not combine groups
merely because their names or unit strings match.

## Run the complete examples

```sh
moon run example/clock --target js
moon run example/clock --target wasm-gc
moon build --target js
node _build/js/debug/build/zhaojun-coding-2/mdf4/cmd/inspect/inspect.js analysis/clock_fixture/milliseconds.mf4 --index 2
node _build/js/debug/build/zhaojun-coding-2/mdf4/cmd/export/export.js analysis/clock_fixture/milliseconds.mf4 "750,1000,1250" signal 3 linear
```

The last command deliberately demonstrates the existing native numeric behavior:
its legacy `time_s` column contains 750,1000,1250, not 0.75,1,1.25. Do not describe
that output as seconds. Replacing its raster with `0.75,1,1.25` returns three
invalid cells. The seconds fixture's corresponding native raster is `0.75,1,1.25`.

`example/clock` reads full raw master/signal arrays and metadata, shows both
normalized resampling policies on JS/Wasm-GC, and leaves the unknown-unit case
unconverted. Its output uses binary64 bit strings (or `nan`) for unambiguous
validation, not a new public serialization protocol. The three full independent
expectations and original byte identities are in `validation/clock-cases.json`.
`validation/check_clock.py` also checks seven real existing CLI calls: four full
inspections and three complete CSVs/nine rows. The two new legal MIT fixtures
derive from the existing own catalogue without changing its original records.
