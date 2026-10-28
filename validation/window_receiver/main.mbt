///|
// A separately compiled public-API test receiver, not another product CLI.
extern "js" fn arguments() -> FixedArray[String] = "() => process.argv.slice(2)"

///|
extern "js" fn load(path : String) -> Bytes = "(p) => new Uint8Array(require('node:fs').readFileSync(p))"

///|
struct ScalarView {
  kind : String
  text : String
  bits : Json
  bytes : Array[Int32]
} derive(ToJson)

///|
struct SeriesView {
  name : String
  unit : String
  time_bits : Array[String]
  values : Array[ScalarView]
  valid : Array[Bool]
} derive(ToJson)

///|
struct WindowView {
  channel_index : Int32
  start_record : Int32
  record_count : Int32
  start_ns : String
  raw : Array[ScalarView]
  series : SeriesView
} derive(ToJson)

///|
struct Response {
  stage : String
  error : Json
  invalid_range : Json
  window : Json
  series : Json
  raw : Json
} derive(ToJson)

///|
fn number(kind : String, n : Double) -> ScalarView {
  {
    kind,
    text: "",
    bits: @json.to_json(n.reinterpret_as_uint64().to_string()),
    bytes: [],
  }
}

///|
fn raw_view(value : @mdf.RawValue) -> ScalarView {
  match value {
    @mdf.Unsigned(n) =>
      { kind: "unsigned", text: n.to_string(), bits: Json::null(), bytes: [], }
    @mdf.Signed(n) =>
      { kind: "signed", text: n.to_string(), bits: Json::null(), bytes: [], }
    @mdf.Real(n) => number("real", n)
    @mdf.Text(text) => { kind: "text", text, bits: Json::null(), bytes: [], }
    @mdf.Octets(bytes) =>
      {
        kind: "octets",
        text: "",
        bits: Json::null(),
        bytes: bytes.to_array().map(value => value.to_int()),
      }
  }
}

///|
fn value_view(value : @mdf.Value) -> ScalarView {
  match value {
    @mdf.Number(n) => number("number", n)
    @mdf.Label(text) => { kind: "label", text, bits: Json::null(), bytes: [], }
    @mdf.Data(bytes) =>
      {
        kind: "data",
        text: "",
        bits: Json::null(),
        bytes: bytes.to_array().map(value => value.to_int()),
      }
  }
}

///|
fn series_view(series : @mdf.Series) -> SeriesView {
  {
    name: series.name,
    unit: series.unit,
    time_bits: series.timestamps.map(t => t.reinterpret_as_uint64().to_string()),
    values: series.values.map(value_view),
    valid: series.valid.copy(),
  }
}

///|
fn window_view(window : @mdf.RecordWindow) -> WindowView {
  {
    channel_index: window.channel_index,
    start_record: window.start_record,
    record_count: window.record_count,
    start_ns: window.start_ns.to_string(),
    raw: window.raw.map(raw_view),
    series: series_view(window.series),
  }
}

///|
fn failure(stage : String, error : @mdf.MdfError) -> Response {
  {
    stage,
    error: @json.to_json(error.to_repr().to_string()),
    invalid_range: Json::null(),
    window: Json::null(),
    series: Json::null(),
    raw: Json::null(),
  }
}

///|
fn main raise {
  let args = arguments()
  if args.length() < 5 {
    println(
      "validation receiver: MODE FILE CHANNEL START COUNT [SAMPLES OUTPUT BLOCKS]",
    )
    return
  }
  let index = @string.parse_int(args[2][:], base=10)
  let start = @string.parse_int(args[3][:], base=10)
  let count = @string.parse_int(args[4][:], base=10)
  let defaults = @mdf.Limits::default()
  let samples = if args.length() > 5 {
    @string.parse_int(args[5][:], base=10)
  } else {
    defaults.max_samples
  }
  let output = if args.length() > 6 {
    @string.parse_int(args[6][:], base=10)
  } else {
    defaults.max_output
  }
  let blocks = if args.length() > 7 {
    @string.parse_int(args[7][:], base=10)
  } else {
    defaults.max_blocks
  }
  let file = match
    @mdf.open(load(args[1]), limits={
      max_samples: samples,
      max_output: output,
      max_blocks: blocks,
    }) {
    Err(error) => {
      println(@json.to_json(failure("open_error", error)).stringify())
      return
    }
    Ok(file) => file
  }
  let response : Response = match args[0] {
    "window" =>
      match file.read_window(index, start, count) {
        Err(@mdf.InvalidRange(start, count, available)) =>
          {
            stage: "range_error",
            error: Json::null(),
            invalid_range: @json.to_json([start, count, available]),
            window: Json::null(),
            series: Json::null(),
            raw: Json::null(),
          }
        Err(@mdf.Source(error)) => failure("window_source_error", error)
        Ok(window) =>
          {
            stage: "window_ok",
            error: Json::null(),
            invalid_range: Json::null(),
            window: @json.to_json(window_view(window)),
            series: Json::null(),
            raw: Json::null(),
          }
      }
    "whole" =>
      match file.read_channel(index) {
        Err(error) => failure("whole_error", error)
        Ok(series) =>
          {
            stage: "whole_ok",
            error: Json::null(),
            invalid_range: Json::null(),
            window: Json::null(),
            series: @json.to_json(series_view(series)),
            raw: Json::null(),
          }
      }
    "raw" =>
      match file.read_raw(index) {
        Err(error) => failure("raw_error", error)
        Ok(raw) =>
          {
            stage: "raw_ok",
            error: Json::null(),
            invalid_range: Json::null(),
            window: Json::null(),
            series: Json::null(),
            raw: @json.to_json(raw.map(raw_view)),
          }
      }
    _ =>
      {
        stage: "bad_test_mode",
        error: Json::null(),
        invalid_range: Json::null(),
        window: Json::null(),
        series: Json::null(),
        raw: Json::null(),
      }
  }
  println(@json.to_json(response).stringify())
}
