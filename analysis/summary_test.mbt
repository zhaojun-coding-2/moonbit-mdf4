///|
fn summary_fields(bytes : Bytes, index : Int32) -> Map[String, Json] raise {
  let file = @mdf.open(bytes).unwrap()
  let text = @analysis.channel_summary_json(file, index).unwrap()
  guard @json.parse(text[:]) is Object(fields) else {
    fail("source summary must be a JSON object")
  }
  fields
}

///|
test "selected physical kind and clock differ from raw catalogue metadata" {
  let fields = summary_fields(@summary_fixture.calibrated(), 3)
  assert_eq(
    fields.get("summary_version"),
    Some(Json::string("mdf4.analysis.channel-summary/1")),
  )
  assert_eq(fields.get("file_version"), Some(Json::string("4.10")))
  assert_eq(fields.get("start_ns"), Some(Json::string("18446744073709551615")))
  assert_eq(fields.get("index"), Some(Json::number(3.0)))
  assert_eq(fields.get("group"), Some(Json::number(1.0)))
  assert_eq(fields.get("name"), Some(Json::string("速度🚲")))
  assert_eq(fields.get("unit"), Some(Json::string("m/s")))
  assert_eq(fields.get("sample_count"), Some(Json::number(2.0)))
  assert_eq(fields.get("valid_samples"), Some(Json::number(2.0)))
  assert_eq(fields.get("invalid_samples"), Some(Json::number(0.0)))
  assert_eq(
    fields.get("value_kinds"),
    Some(Json::array([Json::string("label")])),
  )
  assert_eq(fields.get("first_time"), Some(Json::string("10.5")))
  assert_eq(fields.get("last_time"), Some(Json::string("11.5")))
  assert_eq(fields.get("strict_time_order"), Some(Json::boolean(true)))
  let numeric = summary_fields(@summary_fixture.calibrated(), 1)
  assert_eq(
    numeric.get("value_kinds"),
    Some(Json::array([Json::string("number")])),
  )
  assert_eq(numeric.get("valid_samples"), Some(Json::number(1.0)))
  assert_eq(numeric.get("invalid_samples"), Some(Json::number(1.0)))
}

///|
test "source kinds include invalid values and byte data" {
  let fields = summary_fields(@summary_fixture.all_invalid(), 3)
  assert_eq(
    fields.get("value_kinds"),
    Some(Json::array([Json::string("label")])),
  )
  assert_eq(fields.get("sample_count"), Some(Json::number(2.0)))
  assert_eq(fields.get("valid_samples"), Some(Json::number(0.0)))
  assert_eq(fields.get("invalid_samples"), Some(Json::number(2.0)))
  let data = summary_fields(@review.mixed(), 3)
  assert_eq(data.get("value_kinds"), Some(Json::array([Json::string("data")])))
}

///|
test "source clock order and endpoints are preserved" {
  let fields = summary_fields(@summary_fixture.reversed(), 3)
  assert_eq(fields.get("first_time"), Some(Json::string("11.5")))
  assert_eq(fields.get("last_time"), Some(Json::string("10.5")))
  assert_eq(fields.get("strict_time_order"), Some(Json::boolean(false)))
}

///|
test "empty and signed-zero source clocks retain exact endpoint semantics" {
  let empty = summary_fields(@special.empty(), 1)
  assert_eq(empty.get("sample_count"), Some(Json::number(0.0)))
  assert_eq(empty.get("value_kinds"), Some(Json::array([])))
  assert_eq(empty.get("first_time"), Some(Json::null()))
  assert_eq(empty.get("last_time"), Some(Json::null()))
  assert_eq(empty.get("strict_time_order"), Some(Json::boolean(true)))
  let single = summary_fields(@special.single(), 1)
  assert_eq(single.get("sample_count"), Some(Json::number(1.0)))
  assert_eq(single.get("first_time"), Some(Json::string("-0")))
  assert_eq(single.get("last_time"), Some(Json::string("-0")))
}

///|
test "selected read errors propagate without new error variants" {
  let file = @mdf.open(@summary_fixture.calibrated()).unwrap()
  assert_true(
    @analysis.channel_summary_json(file, -1) is Err(@mdf.ChannelNotFound("-1")),
  )
  assert_true(
    @analysis.channel_summary_json(file, 4) is Err(@mdf.ChannelNotFound("4")),
  )
  let unsupported = @mdf.open(@catalog_fixture.unsupported()).unwrap()
  assert_true(
    @analysis.channel_summary_json(unsupported, 1)
    is Err(@mdf.UnsupportedConversion(99)),
  )
}
