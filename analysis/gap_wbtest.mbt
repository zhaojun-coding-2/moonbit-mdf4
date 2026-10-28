///|
test "numeric CSV retains signed zero for values and requested times" {
  let file = @mdf.open(@special.roundtrip()).unwrap()
  let table = align(
    file,
    [{ channel: 1, label: "value", policy: @mdf.Previous, }],
    [-0.0, 1.0, 2.0, 3.0, 4.0, 5.0],
  ).unwrap()
  guard table.columns()[0].values[1] is @mdf.Number(v) else {
    fail("numeric source required")
  }
  assert_eq(v.reinterpret_as_uint64(), 0x8000000000000000UL)
  assert_eq(table.timestamps()[0].reinterpret_as_uint64(), 0x8000000000000000UL)
  assert_true(table.to_csv().contains("\"-0\",\"5e-324\""))
  assert_true(table.to_csv().contains("\"1\",\"-0\",\"true\""))
}

///|
test "gap limit caps held age and linear bracket without erasing values" {
  let file = @mdf.open(@fixture.unsorted()).unwrap()
  let requests = [
    request(1, "held", @mdf.Previous),
    request(3, "linear", @mdf.Linear),
  ]
  let grid = [0.0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875, 1.0]
  let unrestricted = align(file, requests, grid).unwrap()
  assert_eq(unrestricted.max_gap(), None)
  let limited = align_with_gap(file, requests, grid, max_gap=0.25).unwrap()
  assert_eq(limited.max_gap(), Some(0.25))
  assert_eq(limited.timestamps(), grid)
  assert_eq(limited.columns()[0].valid, [
    true, true, true, false, false, false, false, false, false,
  ])
  assert_eq(limited.columns()[1].valid, [
    false, false, true, false, false, false, true, false, false,
  ])
  assert_eq(limited.columns()[1].values[3], @mdf.Number(6.75))
  assert_true(
    limited.to_csv().contains("\"0.375\",\"\",\"false\",\"\",\"false\""),
  )
  assert_eq(
    align_with_gap(file, requests, grid, max_gap=1.0).unwrap().to_csv(),
    unrestricted.to_csv(),
  )
}

///|
test "zero gap keeps exact enum observations, including valid empty labels" {
  let file = @mdf.open(@special.labels()).unwrap()
  let result = align_with_gap(
    file,
    [request(3, "state", @mdf.Previous)],
    [0.0, 0.25, 0.5, 0.75, 1.0],
    max_gap=0.0,
  ).unwrap()
  assert_eq(result.columns()[0].valid, [false, true, false, true, false])
  assert_eq(result.columns()[0].values[3], @mdf.Label(""))
  assert_true(result.to_csv().contains("\"0.75\",\"\",\"true\""))
  assert_true(
    align_with_gap(
      file,
      [request(3, "state", @mdf.Linear)],
      [0.25],
      max_gap=0.0,
    )
    is Err(Channel("state", 3, @mdf.InvalidTime(_))),
  )
}

///|
test "gap validation and zero/single-record files return defined results" {
  let file = @mdf.open(@special.empty()).unwrap()
  let requests = [request(1, "empty", @mdf.Previous)]
  let result = align_with_gap(file, requests, [0.0, 1.0], max_gap=0.0).unwrap()
  assert_eq(result.row_count(), 2)
  assert_eq(result.columns()[0].valid, [false, false])
  let file = @mdf.open(@special.single()).unwrap()
  assert_eq(
    align_with_gap(file, requests, [0.0, 0.125], max_gap=0.0).unwrap().columns()[0].valid,
    [true, false],
  )
  for limit in [-1.0, 0.0 / 0.0, 1.0 / 0.0] {
    assert_true(
      align_with_gap(file, requests, [], max_gap=limit)
      is Err(InvalidRequest(_)),
    )
  }
  let empty = align_with_gap(file, requests, [], max_cells=0, max_gap=0.0).unwrap()
  assert_eq(empty.row_count(), 0)
  assert_eq(empty.max_gap(), Some(0.0))
}

///|
test "extreme finite clocks cap overflowing spans and retain exact observations" {
  let file = @mdf.open(@special.wide_clock()).unwrap()
  let requests = [
    request(0, "held", @mdf.Previous),
    request(0, "linear", @mdf.Linear),
  ]
  let grid = [-1.5e308, 0.0, 1.5e308]
  let result = align_with_gap(file, requests, grid, max_gap=1.6e308).unwrap()
  assert_eq(result.columns()[0].valid, [true, true, true])
  assert_eq(result.columns()[1].valid, [true, false, true])
  assert_eq(result.columns()[1].values[1], @mdf.Number(0.0))
  assert_eq(
    align_with_gap(file, requests, grid, max_gap=1.0e308).unwrap().columns()[0].valid,
    [true, false, true],
  )
}
