///|
fn request(
  channel : Int32,
  label : String,
  policy : @mdf.Interpolation,
) -> ChannelRequest {
  { channel, label, policy, }
}

///|
test "two clocks align with explicit policies and retain mask metadata" {
  let file = @mdf.open(@fixture.unsorted()).unwrap()
  let grid = [0.0, 0.25, 0.5, 0.75, 1.0]
  let table = align(
    file,
    [request(1, "held", @mdf.Previous), request(3, "linear", @mdf.Linear)],
    grid,
  ).unwrap()
  assert_eq(table.start_ns(), file.start_ns())
  assert_eq(table.row_count(), 5)
  assert_eq(table.column_count(), 2)
  assert_eq(table.timestamps(), grid)
  let columns = table.columns()
  assert_eq(columns[0].name, "g0")
  assert_eq(columns[0].channel, 1)
  assert_eq(columns[0].unit, "")
  assert_eq(columns[0].values, [
    @mdf.Number(-3.0),
    @mdf.Number(-3.0),
    @mdf.Number(-3.0),
    @mdf.Number(-3.0),
    @mdf.Number(6.0),
  ])
  assert_eq(columns[0].valid, [true, true, true, true, false])
  assert_eq(columns[1].values[2], @mdf.Number(-28.5))
  assert_eq(columns[1].valid, [false, true, true, true, false])
}

///|
test "index selection disambiguates duplicate source names and repeated policies" {
  let file = @mdf.open(@fixture.unsorted()).unwrap()
  let table = align(
    file,
    [
      request(0, "clock zero", @mdf.Linear),
      request(2, "clock one", @mdf.Linear),
    ],
    [0.25],
  ).unwrap()
  assert_eq(table.columns()[0].name, "time")
  assert_eq(table.columns()[1].name, "time")
  assert_eq(table.columns()[0].values, [@mdf.Number(0.25)])
  assert_eq(table.columns()[1].values, [@mdf.Number(0.25)])
  let table = align(
    file,
    [request(1, "held", @mdf.Previous), request(1, "interpolated", @mdf.Linear)],
    [0.25],
  ).unwrap()
  assert_eq(table.columns()[0].values, [@mdf.Number(-3.0)])
  assert_eq(table.columns()[0].valid, [true])
  assert_eq(table.columns()[1].values, [@mdf.Number(-0.75)])
  assert_eq(table.columns()[1].valid, [false])
}

///|
test "Unicode enum CSV distinguishes valid empty labels from missing cells" {
  let file = @mdf.open(@special.labels()).unwrap()
  let table = align(file, [request(3, "state", @mdf.Previous)], [
    0.0, 0.25, 0.75, 1.0,
  ]).unwrap()
  assert_eq(table.start_ns(), 0xFFFFFFFFFFFFFFFFUL)
  assert_eq(
    table.columns()[0].values[1],
    @mdf.Label("状态,\"就绪\"\n第二行"),
  )
  assert_eq(table.columns()[0].values[2], @mdf.Label(""))
  assert_eq(table.columns()[0].valid, [false, true, true, false])
  assert_eq(
    table.to_csv(),
    "\"start_ns\",\"time_s\",\"state\",\"state__valid\"\r\n" +
    "\"18446744073709551615\",\"0\",\"\",\"false\"\r\n" +
    "\"18446744073709551615\",\"0.25\",\"状态,\"\"就绪\"\"\n第二行\",\"true\"\r\n" +
    "\"18446744073709551615\",\"0.75\",\"\",\"true\"\r\n" +
    "\"18446744073709551615\",\"1\",\"\",\"false\"\r\n",
  )
  assert_true(
    align(file, [request(3, "state", @mdf.Linear)], [0.25])
    is Err(Channel("state", 3, @mdf.InvalidTime(_))),
  )
}

///|
test "table snapshots cannot invalidate stored grid or masks" {
  let file = @mdf.open(@fixture.unsorted()).unwrap()
  let grid = [0.0, 0.5]
  let requests = [request(1, "a", @mdf.Previous)]
  let table = align(file, requests, grid).unwrap()
  let csv = table.to_csv()
  grid[0] = 99.0
  requests[0] = request(3, "changed", @mdf.Linear)
  let columns = table.columns()
  columns[0].values[0] = @mdf.Label("changed")
  columns[0].valid[0] = false
  let copy = table.timestamps()
  copy[0] = 100.0
  assert_eq(table.to_csv(), csv)
  assert_eq(table.columns()[0].label, "a")
  assert_eq(table.timestamps(), [0.0, 0.5])
}

///|
test "request errors reject ambiguity, invalid shape and budgets" {
  let file = @mdf.open(@special.labels()).unwrap()
  assert_true(align(file, [], [0.0]) is Err(InvalidRequest(_)))
  assert_true(
    align(file, [request(1, "", @mdf.Previous)], [0.0])
    is Err(InvalidRequest(_)),
  )
  assert_true(
    align(
      file,
      [request(1, "a", @mdf.Previous), request(3, "a", @mdf.Previous)],
      [0.0],
    )
    is Err(InvalidRequest(_)),
  )
  assert_true(
    align(file, [request(3, "time_s", @mdf.Previous)], [0.0])
    is Err(InvalidRequest(_)),
  )
  assert_true(
    align(
      file,
      [request(3, "a", @mdf.Previous), request(3, "a__valid", @mdf.Previous)],
      [0.0],
    )
    is Err(InvalidRequest(_)),
  )
  assert_true(
    align(file, [request(-1, "bad", @mdf.Previous)], [0.0])
    is Err(Channel("bad", -1, @mdf.ChannelNotFound(_))),
  )
  assert_true(
    align(
      file,
      [request(1, "a", @mdf.Previous), request(3, "b", @mdf.Previous)],
      [0.0],
      max_cells=1,
    )
    is Err(CellLimit),
  )
  assert_true(
    align(file, [request(1, "a", @mdf.Previous)], [0.0], max_cells=-1)
    is Err(InvalidRequest(_)),
  )
  for grid in [[0.0, 0.0], [1.0, 0.0], [0.0 / 0.0], [1.0 / 0.0]] {
    assert_true(
      align(file, [request(1, "a", @mdf.Previous)], grid)
      is Err(InvalidRequest(_)),
    )
  }
}

///|
test "empty raster preserves schema and exact zero-row budget" {
  let file = @mdf.open(@fixture.core_0()).unwrap()
  let table = align(file, [request(1, "a", @mdf.Previous)], [], max_cells=0).unwrap()
  assert_eq(table.row_count(), 0)
  assert_eq(table.column_count(), 1)
  assert_eq(table.columns()[0].values, [])
  assert_eq(
    table.to_csv(),
    "\"start_ns\",\"time_s\",\"a [u]\",\"a [u]__valid\"\r\n",
  )
}

///|
test "byte values and valid non-finite values have explicit CSV representations" {
  let file = @mdf.open(@special.binary()).unwrap()
  let table = align(file, [request(3, "bytes", @mdf.Previous)], [0.25, 0.75]).unwrap()
  assert_eq(table.columns()[0].values, [
    @mdf.Data(b"\x2a\x00"),
    @mdf.Data(b"\x9d\xff"),
  ])
  assert_true(table.to_csv().contains("0x2a00"))
  assert_true(table.to_csv().contains("0x9dff"))
  let file = @mdf.open(@special.nonfinite()).unwrap()
  let index = file.find_channel("identity").unwrap()
  let table = align(file, [request(index, "IEEE", @mdf.Previous)], [
    0.0, 0.1, 0.2,
  ]).unwrap()
  assert_eq(table.columns()[0].valid, [true, true, false])
  assert_true(table.to_csv().contains("\"NaN\",\"true\""))
  assert_true(table.to_csv().contains("\"Infinity\",\"true\""))
  assert_true(table.to_csv().contains("\"\",\"false\""))
}
