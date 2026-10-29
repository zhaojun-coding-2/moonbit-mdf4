///|
/// Replay one complete saved analysis request using the existing align rules.
/// The document stores explicit clock strings, ordered columns and a gap policy;
/// input/output paths and the separate logical-cell budget are not query fields.
#warnings("-result_error_return")
pub fn align_query(
  file : @mdf.MdfFile,
  query_json : String,
  max_cells~ : Int32 = 1000000,
) -> Result[AlignedTable, AnalysisError] {
  let input = match query_json.strip_prefix("\u{FEFF}") {
    Some(rest) => rest
    None => query_json[:]
  }
  let document = @json.parse(input) catch {
    _ => return Err(InvalidRequest("query document must be valid JSON"))
  }
  guard document is Object(fields) else {
    return Err(InvalidRequest("query document must be an object"))
  }
  let field_error = "query fields must be query_version,raster,columns,max_gap_seconds"
  if fields.length() != 4 {
    return Err(InvalidRequest(field_error))
  }
  let (version, raster_json, columns_json, gap_json) = match
    (
      fields.get("query_version"),
      fields.get("raster"),
      fields.get("columns"),
      fields.get("max_gap_seconds"),
    ) {
    (Some(v), Some(r), Some(c), Some(g)) => (v, r, c, g)
    _ => return Err(InvalidRequest(field_error))
  }
  guard version is String("mdf4.analysis.query/1") else {
    return Err(InvalidRequest("unsupported query version"))
  }
  let raster = match parse_raster_json(raster_json.stringify()) {
    Ok(points) => points
    Err(error) => return Err(error)
  }
  guard columns_json is Array(columns) else {
    return Err(InvalidRequest("query columns must be an array"))
  }
  let requests : Array[ChannelRequest] = []
  for i, item in columns {
    guard item is Object(column) else {
      return Err(InvalidRequest("query column \{i} must be an object"))
    }
    let column_error = "query column \{i} fields must be channel,label,policy"
    if column.length() != 3 {
      return Err(InvalidRequest(column_error))
    }
    let (channel_json, label_json, policy_json) = match
      (column.get("channel"), column.get("label"), column.get("policy")) {
      (Some(c), Some(l), Some(p)) => (c, l, p)
      _ => return Err(InvalidRequest(column_error))
    }
    let (channel_text, label, policy_text) = match
      (channel_json, label_json, policy_json) {
      (String(c), String(l), String(p)) => (c, l, p)
      _ =>
        return Err(
          InvalidRequest(
            "query column \{i} channel,label,policy must be strings",
          ),
        )
    }
    let channel_error = "query column \{i} channel must be nonnegative decimal Int32"
    if channel_text == "" {
      return Err(InvalidRequest(channel_error))
    }
    for c in channel_text.to_array() {
      if c < '0' || c > '9' {
        return Err(InvalidRequest(channel_error))
      }
    }
    let channel = @string.parse_int(channel_text[:], base=10) catch {
      _ => return Err(InvalidRequest(channel_error))
    }
    let policy = match policy_text {
      "previous" => @mdf.Previous
      "linear" => @mdf.Linear
      _ =>
        return Err(
          InvalidRequest("query column \{i} policy must be previous or linear"),
        )
    }
    requests.push({ channel, label, policy, })
  }
  let gap = match gap_json {
    Null => None
    String(value) => {
      let seconds = @string.parse_double(value[:]) catch {
        _ => return Err(InvalidRequest("invalid max_gap_seconds"))
      }
      Some(seconds)
    }
    _ =>
      return Err(
        InvalidRequest("max_gap_seconds must be a decimal string or null"),
      )
  }
  match gap {
    None => align(file, requests, raster, max_cells~)
    Some(max_gap) =>
      align_with_gap(file, requests, raster, max_gap~, max_cells~)
  }
}
