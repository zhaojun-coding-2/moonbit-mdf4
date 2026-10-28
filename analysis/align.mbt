///|
/// Align selected channels without changing the file origin or dropping rows.
/// max_cells bounds grid length times selected-column count, not peak bytes.
#warnings("-result_error_return")
pub fn align(
  file : @mdf.MdfFile,
  requests : Array[ChannelRequest],
  raster : Array[Double],
  max_cells~ : Int32 = 1000000,
) -> Result[AlignedTable, AnalysisError] {
  align_impl(file, requests, raster, max_cells, None)
}

///|
/// Bound held-value age (Previous) or full interpolation span (Linear).
/// Exact observations retain their original validity. The limit is inclusive.
#warnings("-result_error_return")
pub fn align_with_gap(
  file : @mdf.MdfFile,
  requests : Array[ChannelRequest],
  raster : Array[Double],
  max_gap~ : Double,
  max_cells~ : Int32 = 1000000,
) -> Result[AlignedTable, AnalysisError] {
  align_impl(file, requests, raster, max_cells, Some(max_gap))
}

///|
#warnings("-result_error_return")
fn align_impl(
  file : @mdf.MdfFile,
  requests : Array[ChannelRequest],
  raster : Array[Double],
  max_cells : Int32,
  max_gap : Double?,
) -> Result[AlignedTable, AnalysisError] {
  match max_gap {
    Some(limit) =>
      if limit.is_nan() || limit.is_inf() || limit < 0.0 {
        return Err(InvalidRequest("max_gap must be finite and nonnegative"))
      }
    None => ()
  }
  if requests.is_empty() {
    return Err(InvalidRequest("select at least one channel"))
  }
  if max_cells < 0 {
    return Err(InvalidRequest("negative cell budget"))
  }
  if raster.length() > max_cells / requests.length() {
    return Err(CellLimit)
  }
  for i, t in raster {
    if t.is_nan() || t.is_inf() || (i > 0 && t <= raster[i - 1]) {
      return Err(
        InvalidRequest("raster must be finite and strictly increasing"),
      )
    }
  }
  let labels : Array[String] = []
  for request in requests {
    if request.label == "" || labels.contains(request.label) {
      return Err(InvalidRequest("column labels must be nonempty and unique"))
    }
    labels.push(request.label)
  }
  let headers = ["start_ns", "time_s"]
  let columns : Array[AlignedColumn] = []
  for request in requests {
    let source = match file.read_channel(request.channel) {
      Ok(source) => source
      Err(error) => return Err(Channel(request.label, request.channel, error))
    }
    let header = value_header(request.label, source.unit)
    let validity_header = "\{header}__valid"
    if headers.contains(header) || headers.contains(validity_header) {
      return Err(InvalidRequest("generated CSV headers must be unique"))
    }
    headers.push(header)
    headers.push(validity_header)
    let aligned = match @mdf.resample(source, raster, request.policy) {
      Ok(series) => series
      Err(error) => return Err(Channel(request.label, request.channel, error))
    }
    if max_gap is Some(limit) {
      limit_gaps(
        source.timestamps,
        raster,
        request.policy,
        limit,
        aligned.valid,
      )
    }
    columns.push({
      channel: request.channel,
      label: request.label,
      name: source.name,
      unit: source.unit,
      policy: request.policy,
      values: aligned.values,
      valid: aligned.valid,
    })
  }
  Ok({
    origin: file.start_ns(),
    grid: raster.copy(),
    data: columns,
    gap: max_gap,
  })
}
