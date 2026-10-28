///|
struct Report {
  channel_index : Int32
  start_record : Int32
  record_count : Int32
  start_ns : String
  name : String
  unit : String
  raw : Array[String]
  timestamps : Array[Double]
  values : Array[String]
  valid : Array[Bool]
} derive(ToJson)

///|
fn main {
  let file = @mdf.open(@fixture.calibrated()).unwrap()
  // Native record 1 of this group, not interleaved-file record 1 or a time cut.
  let window = file.read_window(3, 1, 1).unwrap()
  let report : Report = {
    channel_index: window.channel_index,
    start_record: window.start_record,
    record_count: window.record_count,
    start_ns: window.start_ns.to_string(),
    name: window.series.name,
    unit: window.series.unit,
    raw: window.raw.map(value => {
      match value {
        @mdf.Signed(n) => n.to_string()
        _ => "unexpected raw kind"
      }
    }),
    timestamps: window.series.timestamps,
    values: window.series.values.map(value => {
      match value {
        @mdf.Label(text) => text
        _ => "unexpected physical kind"
      }
    }),
    valid: window.series.valid,
  }
  println(@json.to_json(report).stringify())
}
