///|
fn main {
  match @mdf.open(@fixture.core_2()) {
    Err(_) => println("could not open sample")
    Ok(m) =>
      match m.extract_channel("linear") {
        Err(_) => println("could not read channel")
        Ok(s) => {
          println(
            "MDF \{m.version()}, channel \{s.name}, \{s.values.length()} samples",
          )
          for i, v in s.values {
            if v is @mdf.Number(n) {
              println("t=\{s.timestamps[i]} value=\{n} valid=\{s.valid[i]}")
            }
          }
        }
      }
  }
}
