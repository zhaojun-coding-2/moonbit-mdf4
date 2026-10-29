///|
struct Report {
  version : String
  start_ns : String
  raw_le : Array[String]
  raw_be : Array[String]
  values_le : Array[String]
  values_be : Array[String]
  timestamps : Array[Double]
  valid_le : Array[Bool]
  valid_be : Array[Bool]
  window_le : Array[String]
  window_valid : Array[Bool]
  csv : String
  schema_json : String
} derive(ToJson)

///|
fn text(value : @mdf.RawValue) -> String {
  match value {
    @mdf.Text(s) => s
    _ => "unexpected raw kind"
  }
}

///|
fn label(value : @mdf.Value) -> String {
  match value {
    @mdf.Label(s) => s
    _ => "unexpected physical kind"
  }
}

///|
fn main {
  let file = @mdf.open(@fixture.utf16_0()).unwrap()
  let le = file.read_channel(1).unwrap()
  let be = file.read_channel(2).unwrap()
  let window = file.read_window(1, 1, 2).unwrap()
  let table = @analysis.align(
    file,
    [
      { channel: 1, label: "le", policy: @mdf.Previous, },
      { channel: 2, label: "be", policy: @mdf.Previous, },
    ],
    [0.0, 1.0, 2.0, 3.0, 4.0, 5.0],
  ).unwrap()
  let report : Report = {
    version: file.version(),
    start_ns: file.start_ns().to_string(),
    raw_le: file.read_raw(1).unwrap().map(text),
    raw_be: file.read_raw(2).unwrap().map(text),
    values_le: le.values.map(label),
    values_be: be.values.map(label),
    timestamps: le.timestamps,
    valid_le: le.valid,
    valid_be: be.valid,
    window_le: window.raw.map(text),
    window_valid: window.series.valid,
    csv: table.to_csv(),
    schema_json: table.schema_json(),
  }
  println(@json.to_json(report).stringify())
}
