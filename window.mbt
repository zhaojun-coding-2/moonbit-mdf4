///|
/// InvalidRange carries requested start/count and the group's record count.
/// Source preserves an existing channel, metadata or selected-sample error.
pub(all) suberror WindowError {
  InvalidRange(Int32, Int32, Int32)
  Source(MdfError)
} derive(Debug, Eq)

///|
/// A caller-owned snapshot in the group's original demultiplexed record order.
/// All four raw/Series arrays have record_count entries; start_ns is not rebased.
pub(all) struct RecordWindow {
  channel_index : Int32
  start_record : Int32
  record_count : Int32
  start_ns : UInt64
  raw : Array[RawValue]
  series : Series
} derive(Debug)

///|
pub extend WindowError with @debug.Debug::{to_repr}

///|
pub extend WindowError with Eq::{equal, not_equal}

///|
pub extend RecordWindow with @debug.Debug::{to_repr}

///|
/// Decode only start_record/count samples after the normal full-file open.
/// Empty windows still validate the unique master and conversion metadata.
/// Success does not certify the physical readability of unselected records.
#warnings("-result_error_return")
pub fn MdfFile::read_window(
  self : MdfFile,
  index : Int32,
  start_record : Int32,
  count : Int32,
) -> Result[RecordWindow, WindowError] {
  let c = self.channel_at(index) catch { error => return Err(Source(error)) }
  let g = self.groups[c.group]
  let available = g.records.length()
  // Short-circuit validation makes available-start safe; do not sum first.
  if start_record < 0 ||
    count < 0 ||
    start_record > available ||
    count > available - start_record {
    return Err(InvalidRange(start_record, count, available))
  }
  try {
    // Preserve series_checked's metadata and per-record source-error order.
    let mut master : Channel? = None
    for candidate in self.channels_ {
      if candidate.group == c.group &&
        candidate.kind == 2 &&
        candidate.sync == 1 {
        if master is Some(_) {
          raise InvalidTime("multiple time masters")
        }
        master = Some(candidate)
      }
    }
    let m = match master {
      Some(value) => value
      None => raise InvalidTime("no time master")
    }
    let conv = read_conversion(self.bytes, c.conversion_address, 0)
    let mconv = read_conversion(self.bytes, m.conversion_address, 0)
    let raw : Array[RawValue] = []
    let values : Array[Value] = []
    let times : Array[Double] = []
    let valid : Array[Bool] = []
    for offset in 0..<count {
      let r = g.records[start_record + offset]
      let master_raw = raw_sample(r, m, g.size)
      let t = match convert_checked(mconv, master_raw) {
        Number(t) => t
        _ => raise InvalidTime("non-numeric master")
      }
      if !finite(t) || !valid_sample(r, m, g) {
        raise InvalidTime("invalid master sample")
      }
      times.push(t)
      let sample = if c.address == m.address {
        master_raw
      } else {
        raw_sample(r, c, g.size)
      }
      let value = convert_checked(conv, sample)
      let sample_valid = valid_sample(r, c, g)
      // Bytes are immutable; the mutable raw and physical arrays are separate.
      raw.push(sample)
      values.push(value)
      valid.push(sample_valid)
    }
    Ok({
      channel_index: index,
      start_record,
      record_count: count,
      start_ns: self.start_ns_,
      raw,
      series: { name: c.name, unit: c.unit, timestamps: times, values, valid, },
    })
  } catch {
    error => Err(Source(error))
  }
}
