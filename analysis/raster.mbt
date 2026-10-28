///|
/// Parse an explicit JSON array of decimal clock strings, optionally with BOM.
/// The actual Double points must be finite and strictly increasing; [] is valid.
/// For example, parse_raster_json("[\"-0\",\"0.25\"]") retains both points.
/// No cadence, sorting or deduplication is inferred; align applies cell budgets.
#warnings("-result_error_return")
pub fn parse_raster_json(text : String) -> Result[Array[Double], AnalysisError] {
  let input = match text.strip_prefix("\u{FEFF}") {
    Some(rest) => rest
    None => text[:]
  }
  let document = @json.parse(input) catch {
    _ => return Err(InvalidRequest("raster document must be valid JSON"))
  }
  guard document is Array(items) else {
    return Err(
      InvalidRequest("raster document must be an array of clock strings"),
    )
  }
  let raster : Array[Double] = []
  for i, item in items {
    guard item is String(clock) else {
      return Err(InvalidRequest("raster point \{i} must be a clock string"))
    }
    let value = @string.parse_double(clock[:]) catch {
      _ => return Err(InvalidRequest("invalid raster clock at index \{i}"))
    }
    if value.is_nan() || value.is_inf() || (i > 0 && value <= raster[i - 1]) {
      return Err(
        InvalidRequest("raster clocks must be finite and strictly increasing"),
      )
    }
    raster.push(value)
  }
  Ok(raster)
}
