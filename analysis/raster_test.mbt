///|
test "raster clock strings preserve independent binary64 reference bits" {
  let values = @analysis.parse_raster_json(
    (
      #|["-0","5e-324","0.29","1.7976931348623157e308"]
    ),
  ).unwrap()
  let expected : Array[UInt64] = [
    0x8000000000000000UL, 0x0000000000000001UL, 0x3fd28f5c28f5c28fUL, 0x7fefffffffffffffUL,
  ]
  assert_eq(values.length(), expected.length())
  for i, value in values {
    assert_eq(value.reinterpret_as_uint64(), expected[i])
  }
}

///|
test "explicit empty and BOM documents are accepted without generated points" {
  assert_eq(@analysis.parse_raster_json("[]").unwrap(), [])
  let values = @analysis.parse_raster_json("\u{FEFF}[\"-0\",\"0.25\"]\n").unwrap()
  assert_eq(values.length(), 2)
  assert_eq(values[0].reinterpret_as_uint64(), 0x8000000000000000UL)
  assert_eq(values[1].reinterpret_as_uint64(), 0x3fd0000000000000UL)
}

///|
test "raster documents require a complete JSON array of strings" {
  for
    input in [
      "", "{}", "null", "[0]", "[true]", "[[\"0\"]]", "[] false", "[\"0\"",
    ] {
    assert_true(
      @analysis.parse_raster_json(input) is Err(@analysis.InvalidRequest(_)),
    )
  }
}

///|
test "raster lexical finite and actual clock ordering errors are explicit" {
  for
    input in [
      (
        #|[""]
      ),
      (
        #|["no"]
      ),
      (
        #|["NaN"]
      ),
      (
        #|["Infinity"]
      ),
      (
        #|["1e999"]
      ),
      (
        #|["0","-0"]
      ),
      (
        #|["1","0"]
      ),
      (
        #|["10.5","10.50000000000000001"]
      ),
    ] {
    assert_true(
      @analysis.parse_raster_json(input) is Err(@analysis.InvalidRequest(_)),
    )
  }
}
