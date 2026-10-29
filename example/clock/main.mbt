///|
priv struct Snapshot {
  times : Array[String]
  values : Array[String]
  valid : Array[Bool]
} derive(ToJson)

///|
priv struct Normalized {
  divisor : String
  seconds : Snapshot
  previous : Snapshot
  linear : Snapshot
} derive(ToJson)

///|
priv struct Output {
  case : String
  file_version : String
  start_ns : String
  channel_index : Int32
  group_index : Int32
  master_index : Int32
  master_unit : String
  source_name : String
  source_unit : String
  raw_master : Array[String]
  raw_values : Array[String]
  native : Snapshot
  decision : String
  normalization : Json
} derive(ToJson)

///|
fn bits(value : Double) -> String {
  if value.is_nan() {
    return "nan"
  }
  let mut text = value.reinterpret_as_uint64().to_string(radix=16)
  while text.length() < 16 {
    text = "0" + text
  }
  text
}

///|
fn snapshot(series : @mdf.Series) -> Snapshot {
  {
    times: series.timestamps.map(bits),
    values: series.values.map(value => {
      match value {
        @mdf.Number(number) => bits(number)
        _ => abort("these owned examples have numeric physical signals")
      }
    }),
    valid: series.valid.copy(),
  }
}

///|
fn raw(value : @mdf.RawValue) -> String {
  match value {
    @mdf.Real(number) => "real:" + bits(number)
    @mdf.Signed(number) => "signed:" + number.to_string()
    _ => abort("these owned examples have Real clocks and Signed signals")
  }
}

///|
fn main {
  let inputs = [
    ("milliseconds", @clock_fixture.milliseconds(), 3, 2),
    ("seconds", @clock_fixture.seconds(), 3, 2),
    ("unknown-unit", @catalog.catalog(), 1, 0),
  ]
  let outputs : Array[Output] = []
  for (name, bytes, index, master_index) in inputs {
    let file = @mdf.open(bytes).unwrap()
    let channels = file.channels()
    let source = file.read_channel(index).unwrap()
    let master_unit = channels[master_index].unit
    // These two owned fixtures have an explicit producer contract. This match
    // is not a generic unit parser or permission to guess an unknown clock.
    let divisor = match master_unit {
      "ms" => Some(1000.0)
      "s" => Some(1.0)
      _ => None
    }
    let normalization = match divisor {
      None => Json::null()
      Some(divisor) => {
        // Copy/transform only timestamps. Values, units, invalid bits and the
        // original native coordinate array remain unchanged.
        let seconds : @mdf.Series = {
          ..source,
          timestamps: source.timestamps.map(t => t / divisor),
        }
        let raster = [0.75, 1.0, 1.25, 1.5]
        let normalized : Normalized = {
          divisor: if master_unit == "ms" {
            "1000"
          } else {
            "1"
          },
          seconds: snapshot(seconds),
          previous: snapshot(
            @mdf.resample(seconds, raster, @mdf.Previous).unwrap(),
          ),
          linear: snapshot(@mdf.resample(seconds, raster, @mdf.Linear).unwrap()),
        }
        @json.to_json(normalized)
      }
    }
    outputs.push({
      case: name,
      file_version: file.version(),
      start_ns: file.start_ns().to_string(),
      channel_index: index,
      group_index: channels[index].group,
      master_index,
      master_unit,
      source_name: source.name,
      source_unit: source.unit,
      raw_master: file.read_raw(master_index).unwrap().map(raw),
      raw_values: file.read_raw(index).unwrap().map(raw),
      native: snapshot(source),
      decision: match divisor {
        None => "caller_clock_contract_required"
        Some(_) => "explicit_owned_" + master_unit + "_contract"
      },
      normalization,
    })
  }
  println(@json.to_json(outputs).stringify())
}
