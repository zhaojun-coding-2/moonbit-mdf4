///|
priv struct NumericPointView {
  record_index : Int32
  time : String
  value : String
} derive(ToJson)

///|
priv struct NumericProfileView {
  profile_version : String
  file_version : String
  start_ns : String
  channel_index : Int32
  group_index : Int32
  master_channel_index : Int32
  name : String
  unit : String
  master_unit : String
  time_unit : String
  sample_count : Int32
  invalid_samples : Int32
  finite_samples : Int32
  nan_samples : Int32
  positive_infinity_samples : Int32
  negative_infinity_samples : Int32
  numeric_kind_observed : Bool
  strict_time_order : Bool
  minimum : Json
  maximum : Json
} derive(ToJson)

///|
fn profile_point_json(point : NumericExtremum?) -> Json {
  match point {
    None => Json::null()
    Some(point) => {
      let view : NumericPointView = {
        record_index: point.record_index,
        time: csv_number(point.time),
        value: csv_number(point.value),
      }
      @json.to_json(view)
    }
  }
}

///|
/// Serialize this profile; finite point values/times use binary64 decimal
/// strings, preserving -0. The UInt64 origin is an exact decimal string.
pub fn NumericProfile::to_json_string(self : NumericProfile) -> String {
  let view : NumericProfileView = {
    profile_version: "mdf4.analysis.numeric-profile/1",
    file_version: self.file_version,
    start_ns: self.start_ns.to_string(),
    channel_index: self.channel_index,
    group_index: self.group_index,
    master_channel_index: self.master_channel_index,
    name: self.name,
    unit: self.unit,
    master_unit: self.master_unit,
    time_unit: "native_master_physical",
    sample_count: self.sample_count,
    invalid_samples: self.invalid_samples,
    finite_samples: self.finite_samples,
    nan_samples: self.nan_samples,
    positive_infinity_samples: self.positive_infinity_samples,
    negative_infinity_samples: self.negative_infinity_samples,
    numeric_kind_observed: self.numeric_kind_observed,
    strict_time_order: self.strict_time_order,
    minimum: profile_point_json(self.minimum),
    maximum: profile_point_json(self.maximum),
  }
  @json.to_json(view).stringify()
}
