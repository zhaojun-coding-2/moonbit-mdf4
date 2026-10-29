///|
fn query_column(channel : String, label : String, policy : String) -> Json {
  Json::object({
    "channel": Json::string(channel),
    "label": Json::string(label),
    "policy": Json::string(policy),
  })
}

///|
fn query_document(
  points : Array[String],
  columns : Array[Json],
  gap : Json,
) -> String {
  Json::object({
    "query_version": Json::string("mdf4.analysis.query/1"),
    "raster": Json::array(points.map(t => Json::string(t))),
    "columns": Json::array(columns),
    "max_gap_seconds": gap,
  }).stringify()
}

///|
test "saved query returns the complete literal calibrated result" {
  let file = @mdf.open(@summary_fixture.calibrated()).unwrap()
  let query = query_document(
    ["10.5", "10.75", "11.25", "11.5"],
    [query_column("3", "state 🚦", "previous")],
    Json::string("0.25"),
  )
  let table = @analysis.align_query(file, query).unwrap()
  assert_eq(table.start_ns(), 18446744073709551615UL)
  assert_eq(table.timestamps(), [10.5, 10.75, 11.25, 11.5])
  assert_eq(table.max_gap(), Some(0.25))
  let column = table.columns()[0]
  assert_eq(column.channel, 3)
  assert_eq(column.name, "速度🚲")
  assert_eq(column.unit, "m/s")
  assert_eq(column.valid, [true, true, false, true])
  assert_eq(column.values, [
    @mdf.Label("前进"),
    @mdf.Label("前进"),
    @mdf.Label("前进"),
    @mdf.Label("倒车"),
  ])
  let unrestricted = @analysis.align_query(
    file,
    query_document(
      ["10.5", "10.75", "11.25", "11.5"],
      [query_column("3", "state 🚦", "previous")],
      Json::null(),
    ),
  ).unwrap()
  assert_eq(unrestricted.columns()[0].valid, [true, true, true, true])
  assert_eq(unrestricted.max_gap(), None)
}

///|
test "query order text policy bytes BOM zero and empty raster reach public output" {
  let file = @mdf.open(@review.mixed()).unwrap()
  let query = query_document(
    ["-0", "0.25", "1"],
    [
      query_column("0003", "bytes,\n\"🧪\"", "previous"),
      query_column("1", "number", "linear"),
      query_column("2", "--query", "previous"),
    ],
    Json::null(),
  )
  let table = @analysis.align_query(file, "\u{FEFF}" + query).unwrap()
  assert_eq(table.column_count(), 3)
  assert_eq(table.timestamps()[0].reinterpret_as_uint64(), 0x8000000000000000UL)
  let columns = table.columns()
  assert_eq(columns.map(c => c.channel), [3, 1, 2])
  assert_eq(columns[1].values, [
    @mdf.Number(1.0),
    @mdf.Number(1.25),
    @mdf.Number(2.0),
  ])
  assert_eq(columns[2].values, [
    @mdf.Label("1"),
    @mdf.Label("1"),
    @mdf.Label("2"),
  ])
  assert_eq(
    columns[0].values[0],
    @mdf.Data(b"\x00\x00\x00\x00\x00\x00\xf0\x3f"),
  )
  assert_eq(
    columns[0].values[2],
    @mdf.Data(b"\x00\x00\x00\x00\x00\x00\x00\x40"),
  )
  let empty = @analysis.align_query(
    file,
    query_document([], [query_column("1", "n", "linear")], Json::null()),
    max_cells=0,
  ).unwrap()
  assert_eq(empty.row_count(), 0)
  assert_eq(empty.columns()[0].values, [])
  assert_eq(
    empty.to_csv(),
    "\"start_ns\",\"time_s\",\"n [u]\",\"n [u]__valid\"\r\n",
  )
  // Mutating a returned snapshot cannot change a replayed table or source.
  columns[1].values[0] = @mdf.Number(99.0)
  assert_eq(table.columns()[1].values[0], @mdf.Number(1.0))
  assert_eq(
    @analysis.align_query(file, query).unwrap().columns()[1].values[0],
    @mdf.Number(1.0),
  )
}

///|
test "query object contract does not silently coerce or ignore settings" {
  let file = @mdf.open(@summary_fixture.calibrated()).unwrap()
  let valid = query_document(
    ["10.5"],
    [query_column("3", "s", "previous")],
    Json::null(),
  )
  for
    text in [
      "",
      "[]",
      "null",
      "{}",
      "\u{FEFF}\u{FEFF}" + valid,
      valid + " false",
    ] {
    assert_true(
      @analysis.align_query(file, text) is Err(@analysis.InvalidRequest(_)),
    )
  }
  for
    (old, new) in [
      ("mdf4.analysis.query/1", "unknown"),
      ("\"raster\"", "\"other\""),
      ("\"channel\"", "\"index\""),
      ("\"3\"", "3"),
      ("\"previous\"", "true"),
      ("\"max_gap_seconds\":null", "\"max_gap_seconds\":false"),
    ] {
    assert_true(
      @analysis.align_query(file, valid.replace(old~, new~))
      is Err(@analysis.InvalidRequest(_)),
    )
  }
}

///|
test "query channel raster policy and gap lexical errors are explicit" {
  let file = @mdf.open(@summary_fixture.calibrated()).unwrap()
  for
    channel in [
      "", "-1", "+3", " 3", "３", "2147483648", "9999999999999999999",
    ] {
    assert_true(
      @analysis.align_query(
        file,
        query_document(
          ["10.5"],
          [query_column(channel, "s", "previous")],
          Json::null(),
        ),
      )
      is Err(@analysis.InvalidRequest(_)),
    )
  }
  for points in [["NaN"], ["10.5", "10.5"], ["11.5", "10.5"], ["no"]] {
    assert_true(
      @analysis.align_query(
        file,
        query_document(
          points,
          [query_column("3", "s", "previous")],
          Json::null(),
        ),
      )
      is Err(@analysis.InvalidRequest(_)),
    )
  }
  for gap in ["no", "-1", "NaN", "Infinity"] {
    assert_true(
      @analysis.align_query(
        file,
        query_document(
          ["10.5"],
          [query_column("3", "s", "previous")],
          Json::string(gap),
        ),
      )
      is Err(@analysis.InvalidRequest(_)),
    )
  }
  assert_true(
    @analysis.align_query(
      file,
      query_document(
        ["10.5"],
        [query_column("3", "s", "nearest")],
        Json::null(),
      ),
    )
    is Err(@analysis.InvalidRequest(_)),
  )
}

///|
test "query propagates existing budget source and schema errors without new variants" {
  let file = @mdf.open(@summary_fixture.calibrated()).unwrap()
  assert_true(
    @analysis.align_query(
      file,
      query_document(
        ["10.5", "11.5"],
        [query_column("2147483647", "s", "previous")],
        Json::null(),
      ),
      max_cells=1,
    )
    is Err(@analysis.CellLimit),
  )
  assert_true(
    @analysis.align_query(
      file,
      query_document(["10.5"], [query_column("3", "s", "linear")], Json::null()),
    )
    is Err(
      @analysis.Channel(
        "s",
        3,
        @mdf.InvalidTime("linear interpolation requires numeric values")
      )
    ),
  )
  assert_true(
    @analysis.align_query(
      file,
      query_document(
        ["10.5"],
        [query_column("99", "s", "previous")],
        Json::null(),
      ),
    )
    is Err(@analysis.Channel("s", 99, @mdf.ChannelNotFound("99"))),
  )
  assert_true(
    @analysis.align_query(file, query_document([], [], Json::null()))
    is Err(@analysis.InvalidRequest("select at least one channel")),
  )
  assert_true(
    @analysis.align_query(
      file,
      query_document(
        [],
        [query_column("3", "s", "previous"), query_column("3", "s", "previous")],
        Json::null(),
      ),
    )
    is Err(
      @analysis.InvalidRequest("column labels must be nonempty and unique")
    ),
  )
  let unsupported = @mdf.open(@catalog_fixture.unsupported()).unwrap()
  assert_true(
    @analysis.align_query(
      unsupported,
      query_document([], [query_column("1", "s", "previous")], Json::null()),
    )
    is Err(@analysis.Channel("s", 1, @mdf.UnsupportedConversion(99))),
  )
}
