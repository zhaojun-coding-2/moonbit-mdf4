///|
struct Report {
  start_ns : String
  rows : Int32
  columns : Int32
  csv : String
} derive(ToJson)

///|
fn main {
  let file = @mdf.open(@fixture.unsorted()).unwrap()
  let table = @analysis.align(
    file,
    [
      { channel: 1, label: "held sensor", policy: @mdf.Previous, },
      { channel: 3, label: "linear sensor", policy: @mdf.Linear, },
    ],
    [0.0, 0.25, 0.5, 0.75, 1.0],
  ).unwrap()
  let report : Report = {
    start_ns: table.start_ns().to_string(),
    rows: table.row_count(),
    columns: table.column_count(),
    csv: table.to_csv(),
  }
  println(@json.to_json(report).stringify())
}
