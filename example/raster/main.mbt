///|
struct Report {
  csv : String
  schema_json : String
} derive(ToJson)

///|
fn main {
  let file = @mdf.open(@fixture.calibrated()).unwrap()
  let raster = @analysis.parse_raster_json(
    (
      #|["10.5","10.625","10.9","11.5"]
    ),
  ).unwrap()
  let table = @analysis.align(
    file,
    [{ channel: 3, label: "state", policy: @mdf.Previous, }],
    raster,
  ).unwrap()
  let report : Report = {
    csv: table.to_csv(),
    schema_json: table.schema_json(),
  }
  println(@json.to_json(report).stringify())
}
