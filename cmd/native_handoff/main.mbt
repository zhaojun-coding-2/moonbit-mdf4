///|
priv struct FileView {
  version : String
  start_ns : String
} derive(ToJson)

///|
priv struct WindowView {
  ordinal : String
  channel_index : String
  group_index : String
  master_channel_index : String
  name : String
  unit : String
  master_unit : String
  start_record : String
  record_count : String
  time_unit : String
  time_bits : Array[String]
  raw : Array[Json]
  values : Array[Json]
  valid : Array[Bool]
} derive(ToJson)

///|
priv struct ResultView {
  result_version : String
  file : FileView
  windows : Array[WindowView]
} derive(ToJson)

///|
fn double_bits(value : Double) -> String {
  let mut hex = value.reinterpret_as_uint64().to_string(radix=16)
  while hex.length() < 16 {
    hex = "0" + hex
  }
  hex
}

///|
fn byte_hex(value : Bytes) -> String {
  let out = StringBuilder()
  for byte in value {
    let n = byte.to_uint64()
    if n < 16UL {
      out.write_string("0")
    }
    out.write_string(n.to_string(radix=16))
  }
  out.to_string()
}

///|
fn raw_view(value : @mdf.RawValue) -> Json {
  match value {
    @mdf.Unsigned(n) =>
      @json.to_json({ "kind": "unsigned", "decimal": n.to_string() })
    @mdf.Signed(n) =>
      @json.to_json({ "kind": "signed", "decimal": n.to_string() })
    @mdf.Real(n) => @json.to_json({ "kind": "real", "bits": double_bits(n) })
    @mdf.Text(text) => @json.to_json({ "kind": "text", "text": text })
    @mdf.Octets(bytes) =>
      @json.to_json({ "kind": "octets", "hex": byte_hex(bytes) })
  }
}

///|
fn physical_view(value : @mdf.Value) -> Json {
  match value {
    @mdf.Number(n) =>
      @json.to_json({ "kind": "number", "bits": double_bits(n) })
    @mdf.Label(text) => @json.to_json({ "kind": "label", "text": text })
    @mdf.Data(bytes) =>
      @json.to_json({ "kind": "data", "hex": byte_hex(bytes) })
  }
}

///|
// The host validates the complete request before calling this once. The flat
// array holds channel, asserted group, start, count for every ordered entry.
// One opened file owns the same loaded byte image for the entire collection.
fn collect(source : Bytes, requests : FixedArray[Int32]) -> FixedArray[String] {
  let file = match @mdf.open(source) {
    Ok(file) => file
    Err(error) => return ["", "open: \{error.to_repr()}"]
  }
  let channels = file.channels()
  let windows : Array[WindowView] = []
  for ordinal in 0..<(requests.length() / 4) {
    let at = ordinal * 4
    let index = requests[at]
    let selected = match
      file.read_window(index, requests[at + 2], requests[at + 3]) {
      Ok(window) => window
      Err(error) => return ["", "window \{ordinal}: \{error.to_repr()}"]
    }
    // A successful public read has already validated this global index,
    // range, unique master and conversion metadata, including empty windows.
    let channel = channels[index]
    if channel.group != requests[at + 1] {
      return ["", "window \{ordinal}: expected_group mismatch"]
    }
    let mut master_index = 0
    for i, candidate in channels {
      if candidate.group == channel.group &&
        candidate.kind == 2 &&
        candidate.sync == 1 {
        master_index = i
      }
    }
    windows.push({
      ordinal: ordinal.to_string(),
      channel_index: index.to_string(),
      group_index: channel.group.to_string(),
      master_channel_index: master_index.to_string(),
      name: channel.name,
      unit: channel.unit,
      master_unit: channels[master_index].unit,
      start_record: selected.start_record.to_string(),
      record_count: selected.record_count.to_string(),
      time_unit: "native_master_physical",
      time_bits: selected.series.timestamps.map(double_bits),
      raw: selected.raw.map(raw_view),
      values: selected.series.values.map(physical_view),
      valid: selected.series.valid,
    })
  }
  let result : ResultView = {
    result_version: "mdf4.native-window.result/1",
    file: { version: file.version(), start_ns: file.start_ns().to_string(), },
    windows,
  }
  [@json.to_json(result).stringify()]
}

///|
fn main {
  run_file_cli(collect)
}
