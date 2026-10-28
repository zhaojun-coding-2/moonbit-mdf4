///|
fn main {
  let file = @mdf.open(@fixture.catalog()).unwrap()
  println(@analysis.channel_catalog_json(file))
}
