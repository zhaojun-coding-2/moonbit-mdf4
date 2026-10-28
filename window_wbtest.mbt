///|
test "native windows return first middle tail full and empty paired records" {
  let file = open(@fixture.core_0()).unwrap()
  let first = file.read_window(1, 0, 1).unwrap()
  assert_eq(first.channel_index, 1)
  assert_eq(first.start_record, 0)
  assert_eq(first.record_count, 1)
  assert_eq(first.start_ns, 1793120324061712896UL)
  assert_eq(first.series.name, "identity")
  assert_eq(first.series.unit, "u")
  assert_eq(first.raw, [Unsigned(0UL)])
  assert_eq(first.series.values, [Number(0.0)])
  assert_eq(first.series.timestamps, [0.0])
  assert_eq(first.series.valid, [true])
  let middle = file.read_window(1, 2, 2).unwrap()
  assert_eq(middle.raw, [Unsigned(2UL), Unsigned(3UL)])
  assert_eq(middle.series.values, [Number(2.0), Number(3.0)])
  assert_eq(middle.series.timestamps, [0.2, 0.3])
  assert_eq(middle.series.valid, [false, true])
  let tail = file.read_window(1, 5, 1).unwrap()
  assert_eq(tail.raw, [Unsigned(5UL)])
  assert_eq(tail.series.values, [Number(5.0)])
  let full = file.read_window(1, 0, 6).unwrap()
  assert_eq(full.raw, [
    Unsigned(0UL),
    Unsigned(1UL),
    Unsigned(2UL),
    Unsigned(3UL),
    Unsigned(4UL),
    Unsigned(5UL),
  ])
  assert_eq(full.series.valid, [true, true, false, true, true, true])
  for start in [0, 3, 6] {
    let empty = file.read_window(1, start, 0).unwrap()
    assert_eq(empty.start_record, start)
    assert_eq(empty.record_count, 0)
    assert_eq(empty.raw.length(), 0)
    assert_eq(empty.series.values.length(), 0)
    assert_eq(empty.series.timestamps.length(), 0)
    assert_eq(empty.series.valid.length(), 0)
    assert_eq(empty.series.name, "identity")
  }
}

///|
test "window ranges do not overflow and channel errors precede ranges" {
  let file = open(@fixture.core_0()).unwrap()
  assert_true(file.read_window(1, -1, 0) is Err(InvalidRange(-1, 0, 6)))
  assert_true(file.read_window(1, 0, -1) is Err(InvalidRange(0, -1, 6)))
  assert_true(file.read_window(1, 7, 0) is Err(InvalidRange(7, 0, 6)))
  assert_true(file.read_window(1, 6, 1) is Err(InvalidRange(6, 1, 6)))
  assert_true(
    file.read_window(1, 1, 2147483647) is Err(InvalidRange(1, 2147483647, 6)),
  )
  assert_true(
    file.read_window(1, 2147483647, 2147483647)
    is Err(InvalidRange(2147483647, 2147483647, 6)),
  )
  assert_true(
    file.read_window(-1, -1, 2147483647) is Err(Source(ChannelNotFound("-1"))),
  )
}

///|
test "empty windows still check master and selected conversion metadata" {
  let source = @fixture.core_0()
  let file = open(source).unwrap()
  let linear = file.find_channel("linear").unwrap()
  let cc = block(source, file.channels()[linear].conversion_address)
  let master = block(source, file.channels()[0].address)
  let bytes = source.to_array()
  bytes[cc.data] = b'\x63'
  let unsupported = open(Bytes::from_array(bytes)).unwrap()
  assert_true(
    unsupported.read_window(linear, 0, 0)
    is Err(Source(UnsupportedConversion(99))),
  )
  assert_true(
    unsupported.read_window(linear, 7, 0) is Err(InvalidRange(7, 0, 6)),
  )
  bytes[master.data] = b'\x00'
  let missing = open(Bytes::from_array(bytes)).unwrap()
  assert_true(
    missing.read_window(linear, 0, 0)
    is Err(Source(InvalidTime("no time master"))),
  )
  let bytes = source.to_array()
  let another = block(source, file.channels()[linear].address)
  bytes[another.data] = b'\x02'
  bytes[another.data + 1] = b'\x01'
  let multiple = open(Bytes::from_array(bytes)).unwrap()
  assert_true(
    multiple.read_window(1, 0, 0)
    is Err(Source(InvalidTime("multiple time masters"))),
  )
}

///|
test "paired arrays and byte-array copies do not change source or later windows" {
  let file = open(semantic_text_fixture(10, b"A\x00\xffZ")).unwrap()
  let window = file.read_window(1, 0, 1).unwrap()
  assert_eq(window.raw, [Octets(b"A\x00\xffZ")])
  assert_eq(window.series.values, [Data(b"A\x00\xffZ")])
  match (window.raw[0], window.series.values[0]) {
    (Octets(raw), Data(value)) => {
      let copy = raw.to_array()
      copy[0] = b'\x58'
      assert_eq(raw, b"A\x00\xffZ")
      assert_eq(value, b"A\x00\xffZ")
      window.raw[0] = Text("changed raw array")
      assert_eq(window.series.values[0], Data(b"A\x00\xffZ"))
      window.series.values[0] = Label("changed physical array")
      assert_eq(window.raw[0], Text("changed raw array"))
    }
    _ => assert_true(false)
  }
  assert_eq(file.read_window(1, 0, 1).unwrap().raw, [Octets(b"A\x00\xffZ")])
  assert_eq(file.read_raw(1).unwrap()[0], Octets(b"A\x00\xffZ"))
}

///|
test "native order nonfinite values and bits survive selected-record work" {
  let source = @fixture.core_0()
  let file = open(source).unwrap()
  let channel = block(source, file.channels()[1].address)
  let master = block(source, file.channels()[0].address)
  let dg = block(source, block(source, 64UL).links[0])
  let cg = block(source, dg.links[1])
  let dt = block(source, dg.links[2])
  let stride = uint_le(source, cg.data + 24, 4).to_int() +
    uint_le(source, cg.data + 28, 4).to_int()
  let bytes = source.to_array()
  bytes[channel.data + 2] = b'\x04'
  semantic_put(bytes, channel.data + 8, 64UL, 4)
  let clocks = [1.0, 1.0, -1.0]
  let samples : Array[UInt64] = [
    0x7ff8000000000000UL, 0x7ff0000000000000UL, 0x8000000000000000UL,
  ]
  for i in 0..<3 {
    semantic_put(
      bytes,
      dt.data + i * stride,
      clocks[i].reinterpret_as_uint64(),
      8,
    )
    semantic_put(bytes, dt.data + i * stride + 8, samples[i], 8)
  }
  let changed = open(Bytes::from_array(bytes)).unwrap()
  let window = changed.read_window(1, 0, 3).unwrap()
  assert_eq(window.series.timestamps, [1.0, 1.0, -1.0])
  assert_eq(window.series.valid, [true, true, false])
  assert_true(window.raw[0] is Real(n) && n.is_nan())
  assert_true(window.series.values[0] is Number(n) && n.is_nan())
  assert_true(window.series.values[1] is Number(n) && n.is_inf())
  assert_true(
    window.raw[2] is Real(n) &&
    n.reinterpret_as_uint64() == 0x8000000000000000UL,
  )
  assert_true(
    window.series.values[2] is Number(n) &&
    n.reinterpret_as_uint64() == 0x8000000000000000UL,
  )
  semantic_put(bytes, master.data + 12, 2UL, 4)
  semantic_put(bytes, master.data + 16, 0UL, 4)
  let bad_master = open(Bytes::from_array(bytes)).unwrap()
  assert_true(bad_master.read_window(1, 0, 2) is Ok(_))
  assert_true(
    bad_master.read_window(1, 0, 3)
    is Err(Source(InvalidTime("invalid master sample"))),
  )
}
