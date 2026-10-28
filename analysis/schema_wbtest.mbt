///|
fn schema_fields(table : AlignedTable) -> Map[String, Json] raise {
  guard @json.parse(table.schema_json()[:]) is Object(fields) else {
    fail("schema object required")
  }
  fields
}

///|
fn column_fields(
  schema : Map[String, Json],
  index : Int32,
) -> Map[String, Json] raise {
  guard schema.get("columns") is Some(Array(columns)) else {
    fail("schema columns required")
  }
  guard columns[index] is Object(fields) else { fail("column object required") }
  fields
}

///|
test "schema disambiguates numeric and text selections with identical CSV" {
  let file = @mdf.open(@review.mixed()).unwrap()
  let numeric = align(file, [request(1, "metric", @mdf.Previous)], [0.0, 1.0]).unwrap()
  let text = align(file, [request(2, "metric", @mdf.Previous)], [0.0, 1.0]).unwrap()
  assert_eq(numeric.to_csv(), text.to_csv())
  let number = column_fields(schema_fields(numeric), 0)
  let label = column_fields(schema_fields(text), 0)
  assert_eq(number.get("channel"), Some(Json::number(1.0)))
  assert_eq(label.get("channel"), Some(Json::number(2.0)))
  assert_eq(
    number.get("valid_value_kinds"),
    Some(Json::array([Json::string("number")])),
  )
  assert_eq(
    label.get("valid_value_kinds"),
    Some(Json::array([Json::string("label")])),
  )
}

///|
test "mixed column schema records independent masks and chosen gap settings" {
  let file = @mdf.open(@review.mixed()).unwrap()
  let table = align_with_gap(
    file,
    [
      request(1, "n", @mdf.Linear),
      request(2, "s", @mdf.Previous),
      request(3, "b", @mdf.Previous),
    ],
    [0.0, 0.5, 0.75, 1.0],
    max_gap=0.5,
  ).unwrap()
  assert_eq(table.columns()[0].valid, [true, false, false, true])
  assert_eq(table.columns()[1].valid, [true, true, false, true])
  assert_eq(table.columns()[2].valid, [true, true, false, true])
  let schema = schema_fields(table)
  assert_eq(schema.get("start_ns"), Some(Json::string("18446744073709551615")))
  assert_eq(schema.get("row_count"), Some(Json::number(4.0)))
  assert_eq(schema.get("max_gap_seconds"), Some(Json::string("0.5")))
  let number = column_fields(schema, 0)
  let label = column_fields(schema, 1)
  let bytes = column_fields(schema, 2)
  assert_eq(number.get("valid_rows"), Some(Json::number(2.0)))
  assert_eq(label.get("valid_rows"), Some(Json::number(3.0)))
  assert_eq(bytes.get("invalid_rows"), Some(Json::number(1.0)))
  assert_eq(number.get("interpolation"), Some(Json::string("linear")))
  assert_eq(
    bytes.get("valid_value_kinds"),
    Some(Json::array([Json::string("data")])),
  )
}

///|
test "empty and all-invalid schema avoids guessing an observed Value kind" {
  let file = @mdf.open(@review.mixed()).unwrap()
  let empty = align(file, [request(2, "state", @mdf.Previous)], []).unwrap()
  let schema = schema_fields(empty)
  assert_eq(schema.get("start_ns"), Some(Json::string("18446744073709551615")))
  assert_eq(schema.get("first_time"), Some(Json::null()))
  assert_eq(schema.get("max_gap_seconds"), Some(Json::null()))
  assert_eq(
    column_fields(schema, 0).get("valid_value_kinds"),
    Some(Json::array([])),
  )
  let missing = align(file, [request(2, "state", @mdf.Previous)], [2.0]).unwrap()
  let column = column_fields(schema_fields(missing), 0)
  assert_eq(column.get("valid_rows"), Some(Json::number(0.0)))
  assert_eq(column.get("invalid_rows"), Some(Json::number(1.0)))
  assert_eq(column.get("valid_value_kinds"), Some(Json::array([])))
}

///|
test "schema JSON handles valid non-finite values without emitting JSON numbers" {
  let file = @mdf.open(@special.nonfinite()).unwrap()
  let table = align(file, [request(1, "IEEE", @mdf.Previous)], [0.0, 0.1, 0.2]).unwrap()
  assert_true(@json.valid(table.schema_json()[:]))
  let column = column_fields(schema_fields(table), 0)
  assert_eq(column.get("valid_rows"), Some(Json::number(2.0)))
  assert_eq(
    column.get("valid_value_kinds"),
    Some(Json::array([Json::string("number")])),
  )
}
