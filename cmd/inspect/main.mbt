///|
extern "js" fn arguments() -> FixedArray[String] = "() => process.argv.slice(2)"

///|
extern "js" fn load(path : String) -> Bytes = "(p) => new Uint8Array(require('node:fs').readFileSync(p))"

///|
extern "js" fn failed() -> Unit = "() => { process.exitCode = 1; }"

///|
struct Output {
  name : String
  unit : String
  raw : Array[String]
  timestamps : Array[Double]
  valid : Array[Bool]
  values : Array[Json]
} derive(ToJson)

///|
struct Metadata {
  version : String
  start_ns : String
  channels : Array[String]
} derive(ToJson)

///|
fn main {
  let args = arguments()
  if args.length() < 1 {
    println(
      "Usage: inspect FILE.mf4 [CHANNEL]; without CHANNEL prints metadata",
    )
    failed()
    return
  }
  match @mdf.open(load(args[0])) {
    Err(e) => {
      println("MDF error: \{e.to_repr()}")
      failed()
    }
    Ok(m) =>
      if args.length() == 1 {
        let out : Metadata = {
          version: m.version(),
          start_ns: m.start_ns().to_string(),
          channels: m.channels().map(c => c.name),
        }
        println(@json.to_json(out).stringify())
      } else {
        match m.extract_channel(args[1]) {
          Err(e) => {
            println("channel error: \{e.to_repr()}")
            failed()
          }
          Ok(s) => {
            let raw = match m.find_channel(args[1]) {
              Ok(i) =>
                match m.read_raw(i) {
                  Ok(r) => r
                  Err(_) => []
                }
              Err(_) => []
            }
            let out : Output = {
              name: s.name,
              unit: s.unit,
              raw: raw.map(v => {
                match v {
                  @mdf.Unsigned(n) => n.to_string()
                  @mdf.Signed(n) => n.to_string()
                  @mdf.Real(n) => n.to_string()
                  @mdf.Text(t) => t
                  @mdf.Octets(b) => @debug.Repr(b).to_string()
                }
              }),
              timestamps: s.timestamps,
              valid: s.valid,
              values: s.values.map(v => {
                match v {
                  @mdf.Number(n) => @json.to_json(n)
                  @mdf.Label(t) => @json.to_json(t)
                  @mdf.Data(b) =>
                    @json.to_json(b.to_array().map(v => v.to_int()))
                }
              }),
            }
            println(@json.to_json(out).stringify())
          }
        }
      }
  }
}
