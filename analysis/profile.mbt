///|
/// A finite physical value at its original group-native record and master time.
pub(all) struct NumericExtremum {
  record_index : Int32
  time : Double
  value : Double
} derive(Debug)

///|
/// Counts partition the source: invalid, valid finite, valid NaN, valid +/-Inf.
/// Empty sources have no observed kind. Ties retain the first native record.
pub(all) struct NumericProfile {
  file_version : String
  start_ns : UInt64
  channel_index : Int32
  group_index : Int32
  master_channel_index : Int32
  name : String
  unit : String
  master_unit : String
  sample_count : Int32
  invalid_samples : Int32
  finite_samples : Int32
  nan_samples : Int32
  positive_infinity_samples : Int32
  negative_infinity_samples : Int32
  numeric_kind_observed : Bool
  strict_time_order : Bool
  minimum : NumericExtremum?
  maximum : NumericExtremum?
} derive(Debug)

///|
pub extend NumericExtremum with @debug.Debug::{to_repr}

///|
pub extend NumericProfile with @debug.Debug::{to_repr}

///|
/// Read one physical channel, then locate its valid finite extrema without
/// sorting, resampling, rebasing, or inferring the master unit. All observed
/// physical values must be Number, including invalid samples. Source errors
/// keep read_channel's precedence; a success is not a raw-integer profile.
#warnings("-result_error_return")
pub fn channel_numeric_profile(
  file : @mdf.MdfFile,
  index : Int32,
) -> Result[NumericProfile, @mdf.MdfError] {
  let source = match file.read_channel(index) {
    Ok(source) => source
    Err(error) => return Err(error)
  }
  let channels = file.channels()
  let channel = channels[index]
  // A successful read has checked the global index and the unique same-group
  // time master, even for an empty channel. Metadata remains source-native.
  let mut master_index = 0
  for i, candidate in channels {
    if candidate.group == channel.group &&
      candidate.kind == 2 &&
      candidate.sync == 1 {
      master_index = i
    }
  }
  let mut invalid_samples = 0
  let mut finite_samples = 0
  let mut nan_samples = 0
  let mut positive_infinity_samples = 0
  let mut negative_infinity_samples = 0
  let mut strict_time_order = true
  let mut minimum : NumericExtremum? = None
  let mut maximum : NumericExtremum? = None
  for i, physical in source.values {
    let value = match physical {
      @mdf.Number(value) => value
      _ =>
        return Err(
          @mdf.UnsupportedFeature(
            "numeric profile requires numeric physical values",
          ),
        )
    }
    if i > 0 && source.timestamps[i] <= source.timestamps[i - 1] {
      strict_time_order = false
    }
    if !source.valid[i] {
      invalid_samples += 1
      continue
    }
    if value.is_nan() {
      nan_samples += 1
      continue
    }
    if value.is_inf() {
      if value > 0.0 {
        positive_infinity_samples += 1
      } else {
        negative_infinity_samples += 1
      }
      continue
    }
    finite_samples += 1
    let point : NumericExtremum = {
      record_index: i,
      time: source.timestamps[i],
      value,
    }
    match minimum {
      None => minimum = Some(point)
      Some(current) => if value < current.value { minimum = Some(point) }
    }
    match maximum {
      None => maximum = Some(point)
      Some(current) => if value > current.value { maximum = Some(point) }
    }
  }
  Ok({
    file_version: file.version(),
    start_ns: file.start_ns(),
    channel_index: index,
    group_index: channel.group,
    master_channel_index: master_index,
    name: source.name,
    unit: source.unit,
    master_unit: channels[master_index].unit,
    sample_count: source.values.length(),
    invalid_samples,
    finite_samples,
    nan_samples,
    positive_infinity_samples,
    negative_infinity_samples,
    numeric_kind_observed: !source.values.is_empty(),
    strict_time_order,
    minimum,
    maximum,
  })
}
