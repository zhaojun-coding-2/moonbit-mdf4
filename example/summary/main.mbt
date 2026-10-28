///|
fn main {
  let file = @mdf.open(@fixture.calibrated()).unwrap()
  println(@analysis.channel_summary_json(file, 3).unwrap())
}
