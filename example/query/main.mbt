///|
struct Report {
  csv : String
  schema_json : String
  budget_error : Bool
} derive(ToJson)

///|
fn main {
  let file = @mdf.open(@fixture.calibrated()).unwrap()
  let query =
    #|{"query_version":"mdf4.analysis.query/1","raster":["10.5","10.75","11.25","11.5"],"columns":[{"channel":"3","label":"state 🚦","policy":"previous"}],"max_gap_seconds":"0.25"}
  let table = @analysis.align_query(file, query).unwrap()
  let report : Report = {
    csv: table.to_csv(),
    schema_json: table.schema_json(),
    budget_error: @analysis.align_query(file, query, max_cells=3)
    is Err(@analysis.CellLimit),
  }
  println(@json.to_json(report).stringify())
}
