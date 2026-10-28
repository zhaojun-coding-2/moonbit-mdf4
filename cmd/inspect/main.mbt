///|
extern "js" fn arguments() -> FixedArray[String] = "() => process.argv.slice(2)"

///|
extern "js" fn load(path : String) -> Bytes = "(p) => new Uint8Array(require('node:fs').readFileSync(p))"

///|
extern "js" fn failed() -> Unit = "() => { process.exitCode = 1; }"

///|
extern "js" fn index_error(message : String) -> Unit = "(s) => { process.stderr.write(s + '\n'); process.exitCode = 1; }"

///|
fn report_error(message : String, indexed : Bool) -> Unit {
  if indexed {
    index_error(message)
  } else {
    println(message)
    failed()
  }
}

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
  // The two-argument form keeps every literal channel name, including --index.
  let indexed = args.length() == 3 && args[1] == "--index"
  let selected_index = if indexed {
    let index = @string.parse_int(args[2][:], base=10) catch {
      _ => {
        index_error("Channel index must be a non-negative decimal Int")
        return
      }
    }
    if index < 0 {
      index_error("Channel index must be a non-negative decimal Int")
      return
    }
    Some(index)
  } else {
    None
  }
  match @mdf.open(load(args[0])) {
    Err(e) => report_error("MDF error: \{e.to_repr()}", indexed)
    Ok(m) =>
      if args.length() == 1 {
        let out : Metadata = {
          version: m.version(),
          start_ns: m.start_ns().to_string(),
          channels: m.channels().map(c => c.name),
        }
        println(@json.to_json(out).stringify())
      } else {
        let channel = match selected_index {
          Some(index) => m.read_channel(index)
          None => m.extract_channel(args[1])
        }
        match channel {
          Err(e) => report_error("channel error: \{e.to_repr()}", indexed)
          Ok(s) => {
            let raw_index = match selected_index {
              Some(index) => Ok(index)
              None => m.find_channel(args[1])
            }
            let raw = match raw_index {
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
