///|
extern "js" fn arguments() -> FixedArray[String] = "() => process.argv.slice(2)"

///|
extern "js" fn load(path : String) -> Bytes = "(p) => { try { return new Uint8Array(require('node:fs').readFileSync(p)); } catch (_) { return new Uint8Array(0); } }"

///|
extern "js" fn reject(message : String) -> Unit = "(s) => { process.stderr.write(s + '\n'); process.exitCode = 1; }"

///|
fn main {
  let args = arguments()
  let numeric = args.length() == 3 && args[2] == "--numeric"
  if args.length() != 2 && !numeric {
    reject("Usage: summary FILE.mf4 INDEX [--numeric]")
    return
  }
  let index = @string.parse_int(args[1][:]) catch {
    _ => {
      reject("Channel index must be an integer")
      return
    }
  }
  match @mdf.open(load(args[0])) {
    Err(error) => reject("Cannot open MDF input: \{error.to_repr()}")
    Ok(file) => {
      let result = if numeric {
        match @analysis.channel_numeric_profile(file, index) {
          Ok(profile) => Ok(profile.to_json_string())
          Err(error) => Err(error)
        }
      } else {
        @analysis.channel_summary_json(file, index)
      }
      match result {
        Err(error) => reject("Cannot read channel: \{error.to_repr()}")
        Ok(summary) => println(summary)
      }
    }
  }
}
