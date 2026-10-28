///|
struct Comparison {
  max_gap_seconds : Double
  unrestricted_csv : String
  limited_csv : String
} derive(ToJson)

///|
fn main {
  let file = @mdf.open(@fixture.unsorted()).unwrap()
  let requests : Array[@analysis.ChannelRequest] = [
    { channel: 1, label: "held", policy: @mdf.Previous, },
    { channel: 3, label: "linear", policy: @mdf.Linear, },
  ]
  let grid = [0.0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875, 1.0]
  let unlimited = @analysis.align(file, requests, grid).unwrap()
  let limited = @analysis.align_with_gap(file, requests, grid, max_gap=0.25).unwrap()
  let comparison : Comparison = {
    max_gap_seconds: limited.max_gap().unwrap(),
    unrestricted_csv: unlimited.to_csv(),
    limited_csv: limited.to_csv(),
  }
  println(@json.to_json(comparison).stringify())
}
