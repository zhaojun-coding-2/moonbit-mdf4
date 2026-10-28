///|
priv struct ChannelSummary {
  summary_version : String
  file_version : String
  start_ns : String
  index : Int32
  group : Int32
  name : String
  unit : String
  sample_count : Int32
  valid_samples : Int32
  invalid_samples : Int32
  value_kinds : Array[String]
  first_time : Json
  last_time : Json
  strict_time_order : Bool
} derive(ToJson)

///|
/// Inspect one global index through the existing physical reader.
/// Kinds include invalid source samples; endpoints preserve source order and -0.
/// For example, print the Ok string from channel_summary_json(file, 3).
/// example/summary supplies the owned calibrated-enum file.
#warnings("-result_error_return")
pub fn channel_summary_json(
  file : @mdf.MdfFile,
  index : Int32,
) -> Result[String, @mdf.MdfError] {
  let source = match file.read_channel(index) {
    Ok(source) => source
    Err(error) => return Err(error)
  }
  let channel = file.channels()[index]
  let mut valid_samples = 0
  let mut number = false
  let mut label = false
  let mut data = false
  for i, value in source.values {
    if source.valid[i] {
      valid_samples += 1
    }
    match value {
      @mdf.Number(_) => number = true
      @mdf.Label(_) => label = true
      @mdf.Data(_) => data = true
    }
  }
  let value_kinds : Array[String] = []
  if number {
    value_kinds.push("number")
  }
  if label {
    value_kinds.push("label")
  }
  if data {
    value_kinds.push("data")
  }
  let mut strict_time_order = true
  for i, time in source.timestamps {
    if i > 0 && time <= source.timestamps[i - 1] {
      strict_time_order = false
    }
  }
  let summary : ChannelSummary = {
    summary_version: "mdf4.analysis.channel-summary/1",
    file_version: file.version(),
    start_ns: file.start_ns().to_string(),
    index,
    group: channel.group,
    name: source.name,
    unit: source.unit,
    sample_count: source.values.length(),
    valid_samples,
    invalid_samples: source.values.length() - valid_samples,
    value_kinds,
    first_time: if source.timestamps.is_empty() {
      Json::null()
    } else {
      Json::string(csv_number(source.timestamps[0]))
    },
    last_time: if source.timestamps.is_empty() {
      Json::null()
    } else {
      Json::string(
        csv_number(source.timestamps[source.timestamps.length() - 1]),
      )
    },
    strict_time_order,
  }
  Ok(@json.to_json(summary).stringify())
}
