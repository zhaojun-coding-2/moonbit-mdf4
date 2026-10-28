///|
struct Report {
  csv : String
  schema_json : String
} derive(ToJson)

///|
fn main {
  let file = @mdf.open(@fixture.mixed()).unwrap()
  let requests : Array[@analysis.ChannelRequest] = [
    { channel: 1, label: "number", policy: @mdf.Linear, },
    { channel: 2, label: "state", policy: @mdf.Previous, },
    { channel: 3, label: "bytes", policy: @mdf.Previous, },
  ]
  let table = @analysis.align_with_gap(
    file,
    requests,
    [0.0, 0.5, 0.75, 1.0],
    max_gap=0.5,
  ).unwrap()
  let report : Report = {
    csv: table.to_csv(),
    schema_json: table.schema_json(),
  }
  println(@json.to_json(report).stringify())
}
