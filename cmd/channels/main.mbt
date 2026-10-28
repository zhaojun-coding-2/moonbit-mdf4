///|
extern "js" fn arguments() -> FixedArray[String] = "() => process.argv.slice(2)"

///|
extern "js" fn load(path : String) -> Bytes = "(p) => { try { return new Uint8Array(require('node:fs').readFileSync(p)); } catch (_) { return new Uint8Array(0); } }"

///|
extern "js" fn reject(message : String) -> Unit = "(s) => { process.stderr.write(s + '\n'); process.exitCode = 1; }"

///|
fn main {
  let args = arguments()
  if args.length() != 1 {
    reject("Usage: channels FILE.mf4")
    return
  }
  match @mdf.open(load(args[0])) {
    Err(error) => reject("Cannot open MDF input: \{error.to_repr()}")
    Ok(file) => println(@analysis.channel_catalog_json(file))
  }
}
