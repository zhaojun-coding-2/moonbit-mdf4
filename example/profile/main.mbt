///|
priv struct Input {
  name : String
  bytes : Bytes
  index : Int32
}

///|
priv struct PointBits {
  record_index : Int32
  time_bits : String
  value_bits : String
} derive(ToJson)

///|
priv struct Snapshot {
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
priv struct Output {
  name : String
  error : Json
  typed : Json
  wire : Json
} derive(ToJson)

///|
fn bits(value : Double) -> String {
  let mut text = value.reinterpret_as_uint64().to_string(radix=16)
  while text.length() < 16 {
    text = "0" + text
  }
  text
}

///|
fn point(value : @analysis.NumericExtremum?) -> Json {
  match value {
    None => Json::null()
    Some(value) => {
      let snapshot : PointBits = {
        record_index: value.record_index,
        time_bits: bits(value.time),
        value_bits: bits(value.value),
      }
      @json.to_json(snapshot)
    }
  }
}

///|
fn snapshot(profile : @analysis.NumericProfile) -> Json {
  // Read the public result fields directly outside their owning package.
  let out : Snapshot = {
    profile_version: "mdf4.analysis.numeric-profile/1",
    file_version: profile.file_version,
    start_ns: profile.start_ns.to_string(),
    channel_index: profile.channel_index,
    group_index: profile.group_index,
    master_channel_index: profile.master_channel_index,
    name: profile.name,
    unit: profile.unit,
    master_unit: profile.master_unit,
    time_unit: "native_master_physical",
    sample_count: profile.sample_count,
    invalid_samples: profile.invalid_samples,
    finite_samples: profile.finite_samples,
    nan_samples: profile.nan_samples,
    positive_infinity_samples: profile.positive_infinity_samples,
    negative_infinity_samples: profile.negative_infinity_samples,
    numeric_kind_observed: profile.numeric_kind_observed,
    strict_time_order: profile.strict_time_order,
    minimum: point(profile.minimum),
    maximum: point(profile.maximum),
  }
  @json.to_json(out)
}

///|
fn main raise {
  let inputs : Array[Input] = [
    { name: "catalog-kmh", bytes: @catalog.catalog(), index: 1, },
    { name: "catalog-ms", bytes: @catalog.catalog(), index: 3, },
    { name: "catalog-master", bytes: @catalog.catalog(), index: 2, },
    { name: "nonfinite", bytes: @special.nonfinite(), index: 1, },
    { name: "native-clock", bytes: @profile_fixture.native_real(), index: 1, },
    { name: "signed-zero", bytes: @profile_fixture.signed_zero(), index: 1, },
    { name: "all-invalid", bytes: @profile_fixture.all_invalid(), index: 1, },
    { name: "empty", bytes: @special.empty(), index: 1, },
    { name: "uint64-physical-tie", bytes: @fixture.core_0(), index: 8, },
    { name: "tie-reversed", bytes: @profile_fixture.tie_reversed(), index: 3, },
    {
      name: "all-nonfinite",
      bytes: @profile_fixture.all_nonfinite(),
      index: 1,
    },
    { name: "unsupported-sibling", bytes: @catalog.unsupported(), index: 3, },
    { name: "labels", bytes: @special.labels(), index: 3, },
    { name: "data", bytes: @special.binary(), index: 3, },
    { name: "invalid-labels", bytes: @summary.all_invalid(), index: 3, },
    { name: "numeric-looking-labels", bytes: @review.mixed(), index: 2, },
    { name: "missing-index", bytes: @catalog.catalog(), index: 4, },
    { name: "negative-index", bytes: @catalog.catalog(), index: -1, },
    { name: "unsupported-conversion", bytes: @catalog.unsupported(), index: 1, },
  ]
  let outputs : Array[Output] = []
  for input in inputs {
    let file = @mdf.open(input.bytes).unwrap()
    match @analysis.channel_numeric_profile(file, input.index) {
      Err(error) =>
        outputs.push({
          name: input.name,
          error: @json.to_json(error.to_repr().to_string()),
          typed: Json::null(),
          wire: Json::null(),
        })
      Ok(profile) =>
        outputs.push({
          name: input.name,
          error: Json::null(),
          typed: snapshot(profile),
          wire: @json.parse(profile.to_json_string()),
        })
    }
  }
  println(@json.to_json(outputs).stringify())
}
