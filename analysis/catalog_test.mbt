///|
fn fields(text : String) -> Map[String, Json] raise {
  guard @json.parse(text[:]) is Object(fields) else {
    fail("catalogue must be an object")
  }
  fields
}

///|
fn rows(fields : Map[String, Json]) -> Array[Json] raise {
  guard fields.get("channels") is Some(Array(rows)) else {
    fail("catalogue must contain channels")
  }
  rows
}

///|
fn row_fields(row : Json) -> Map[String, Json] raise {
  guard row is Object(fields) else { fail("channel row must be an object") }
  fields
}

///|
test "catalogue keeps duplicate-name group/unit identity and exact origin" {
  let file = @mdf.open(@catalog_fixture.catalog()).unwrap()
  let fields = fields(@analysis.channel_catalog_json(file))
  assert_eq(
    fields.get("catalogue_version"),
    Some(Json::string("mdf4.analysis.channels/1")),
  )
  assert_eq(fields.get("file_version"), Some(Json::string("4.10")))
  assert_eq(fields.get("start_ns"), Some(Json::string("18446744073709551615")))
  let rows = rows(fields)
  assert_eq(rows.length(), 4)
  let names = ["time", "速度🚲", "time", "速度🚲"]
  let units = ["", "km/h", "", "m/s"]
  for i, row in rows {
    let row = row_fields(row)
    assert_eq(row.get("index"), Some(Json::number(i.to_double())))
    assert_eq(row.get("group"), Some(Json::number((i / 2).to_double())))
    assert_eq(row.get("name"), Some(Json::string(names[i])))
    assert_eq(row.get("unit"), Some(Json::string(units[i])))
    assert_eq(
      row.get("channel_kind"),
      Some(Json::number(if i % 2 == 0 { 2.0 } else { 0.0 })),
    )
    assert_eq(
      row.get("sync_type"),
      Some(Json::number(if i % 2 == 0 { 1.0 } else { 0.0 })),
    )
    assert_eq(
      row.get("data_type"),
      Some(Json::number(if i % 2 == 0 { 4.0 } else { 2.0 })),
    )
    assert_eq(
      row.get("bit_count"),
      Some(Json::number(if i % 2 == 0 { 64.0 } else { 16.0 })),
    )
  }
}

///|
test "catalogue does not execute unsupported physical conversion" {
  let file = @mdf.open(@catalog_fixture.unsupported()).unwrap()
  assert_true(file.read_channel(1) is Err(@mdf.UnsupportedConversion(99)))
  assert_eq(
    @analysis.channel_catalog_json(file),
    @analysis.channel_catalog_json(
      @mdf.open(@catalog_fixture.catalog()).unwrap(),
    ),
  )
}

///|
test "empty channel inventory retains file metadata" {
  let input = @catalog_fixture.catalog().to_array()
  for i in 0..<8 {
    input[88 + i] = b'\x00'
  }
  let file = @mdf.open(Bytes::from_array(input)).unwrap()
  let fields = fields(@analysis.channel_catalog_json(file))
  assert_eq(rows(fields), [])
  assert_eq(fields.get("file_version"), Some(Json::string("4.10")))
  assert_eq(fields.get("start_ns"), Some(Json::string("18446744073709551615")))
}
