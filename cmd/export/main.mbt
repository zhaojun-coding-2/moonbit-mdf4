///|
extern "js" fn arguments() -> FixedArray[String] = "() => process.argv.slice(2)"

///|
extern "js" fn load(path : String) -> Bytes = "(p) => { try { return new Uint8Array(require('node:fs').readFileSync(p)); } catch (_) { return new Uint8Array(0); } }"

///|
extern "js" fn emit(csv : String) -> Unit = "(s) => { process.stdout.write(s); }"

///|
extern "js" fn reject(message : String) -> Unit = "(s) => { process.stderr.write(s + '\n'); process.exitCode = 1; }"

///|
fn main {
  let args = arguments()
  let mut end = args.length()
  let mut max_gap : Double? = None
  let mut receipt_path : String? = None
  while end >= 7 {
    match args[end - 2] {
      "--max-gap" => {
        if max_gap is Some(_) {
          reject("Duplicate --max-gap option")
          return
        }
        let limit = @string.parse_double(args[end - 1][:]) catch {
          _ => {
            reject("Gap limit must be a number of seconds")
            return
          }
        }
        max_gap = Some(limit)
      }
      "--receipt" => {
        if receipt_path is Some(_) {
          reject("Duplicate --receipt option")
          return
        }
        receipt_path = Some(args[end - 1])
      }
      _ => break
    }
    end -= 2
  }
  if end < 5 || (end - 2) % 3 != 0 {
    reject(
      "Usage: export FILE RASTER LABEL INDEX POLICY [LABEL INDEX POLICY ...] [--max-gap SECONDS] [--receipt NEW_PATH]; RASTER is comma-separated seconds or @UTF8_JSON_FILE (array of clock strings); POLICY is previous or linear",
    )
    return
  }
  let raster = match args[1].strip_prefix("@") {
    Some(path) => {
      let bytes = load(path.to_owned())
      let text = @utf8.decode(bytes[:]) catch {
        _ => {
          reject("Raster file must be UTF-8")
          return
        }
      }
      match @analysis.parse_raster_json(text) {
        Ok(raster) => raster
        Err(error) => {
          reject("Cannot read or parse raster file: \{error.to_repr()}")
          return
        }
      }
    }
    None => {
      let raster : Array[Double] = []
      if args[1] != "" {
        for part in args[1].split(",") {
          let value = @string.parse_double(part) catch {
            _ => {
              reject("Invalid raster number")
              return
            }
          }
          raster.push(value)
        }
      }
      raster
    }
  }
  let requests : Array[@analysis.ChannelRequest] = []
  let mut i = 2
  while i < end {
    let index = @string.parse_int(args[i + 1][:]) catch {
      _ => {
        reject("Channel index must be an integer")
        return
      }
    }
    let policy = match args[i + 2] {
      "previous" => @mdf.Previous
      "linear" => @mdf.Linear
      _ => {
        reject("Policy must be previous or linear")
        return
      }
    }
    requests.push({ channel: index, label: args[i], policy, })
    i += 3
  }
  let source = load(args[0])
  let file = match @mdf.open(source) {
    Ok(file) => file
    Err(error) => {
      reject("Cannot open MDF input: \{error.to_repr()}")
      return
    }
  }
  let result = match max_gap {
    Some(limit) =>
      @analysis.align_with_gap(file, requests, raster, max_gap=limit)
    None => @analysis.align(file, requests, raster)
  }
  match result {
    Ok(table) => {
      let csv = table.to_csv()
      if receipt_path is Some(path) {
        if !store_receipt(path, table.schema_json(), source, csv) {
          reject("Could not create receipt; use a new writable path")
          return
        }
      }
      emit(csv)
    }
    Err(error) =>
      reject("Cannot align channels: \{@debug.Repr(error).to_string()}")
  }
}

///|
// Hash the same bytes used by open and the exact UTF-8 string written to stdout.
// Exclusive creation keeps existing files untouched; errors precede CSV output.
extern "js" fn store_receipt(
  path : String,
  schema : String,
  source : Bytes,
  csv : String,
) -> Bool = "(p,s,b,c) => { try { const crypto=require('node:crypto'); const bytes=Buffer.from(c,'utf8'); const hash=x=>crypto.createHash('sha256').update(x).digest('hex'); const receipt={receipt_version:'mdf4.analysis.receipt/1',source:{sha256:hash(b),bytes:b.byteLength},csv:{sha256:hash(bytes),bytes:bytes.byteLength,encoding:'UTF-8',newline:'CRLF'},table:JSON.parse(s)}; require('node:fs').writeFileSync(p,JSON.stringify(receipt,null,2)+String.fromCharCode(10),{encoding:'utf8',flag:'wx'}); return true; } catch (_) { return false; } }"
