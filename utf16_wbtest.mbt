///|
fn utf16_field(
  data_type : Int32,
  payload : Bytes,
) -> Result[RawValue, MdfError] {
  let channel = open(@fixture.utf16_0()).unwrap().channels()[1]
  let c = {
    ..channel,
    data_type,
    byte_offset: 0,
    bit_offset: 0,
    bit_count: payload.length() * 8,
  }
  Ok(raw_sample(payload, c, payload.length())) catch {
    e => Err(e)
  }
}

///|
test "UTF16 LE and BE fixed records reach raw physical masks and exact origin" {
  let file = open(@fixture.utf16_0()).unwrap()
  let text = ["A", "龙🧪", "", "é,\"\nZ", "月兔", "12345678"]
  assert_eq(file.version(), "4.11")
  assert_eq(file.start_ns(), 18446744073709551615UL)
  for index in [1, 2] {
    assert_eq(file.read_raw(index).unwrap(), text.map(t => Text(t)))
    let series = file.read_channel(index).unwrap()
    assert_eq(series.values, text.map(t => Label(t)))
    assert_eq(series.timestamps, [0.0, 1.0, 2.0, 3.0, 4.0, 5.0])
    assert_eq(series.unit, "state")
  }
  assert_eq(file.read_channel(1).unwrap().valid, [
    true, false, true, true, true, true,
  ])
  assert_eq(file.read_channel(2).unwrap().valid, [
    true, true, true, false, true, true,
  ])
}

///|
test "UTF16 terminates on code units and preserves explicit-endian content" {
  assert_eq(utf16_field(8, b"A\x00\x00\x00"), Ok(Text("A")))
  assert_eq(utf16_field(9, b"\x00A\x00\x00"), Ok(Text("A")))
  assert_eq(
    utf16_field(8, b"\x99\x9f\x3e\xd8\xea\xdd\x00\x00"),
    Ok(Text("龙🧪")),
  )
  assert_eq(
    utf16_field(9, b"\x9f\x99\xd8\x3e\xdd\xea\x00\x00"),
    Ok(Text("龙🧪")),
  )
  assert_eq(utf16_field(8, b"\x00\xd8\x00\xdc"), Ok(Text("\u{10000}")))
  assert_eq(utf16_field(9, b"\xdb\xff\xdf\xff"), Ok(Text("\u{10FFFF}")))
  assert_eq(utf16_field(8, b"A\x00B\x00"), Ok(Text("AB")))
  assert_eq(utf16_field(9, b"\x00A\x00B"), Ok(Text("AB")))
  assert_eq(utf16_field(8, b"A\x00\x00\x00\x00\xd8"), Ok(Text("A")))
  assert_eq(utf16_field(9, b"\x00A\x00\x00\xd8\x00"), Ok(Text("A")))
  assert_eq(utf16_field(8, b"\xff\xfeA\x00"), Ok(Text("\u{FEFF}A")))
  assert_eq(utf16_field(9, b"\xfe\xff\x00A"), Ok(Text("\u{FEFF}A")))
  assert_eq(utf16_field(8, b""), Ok(Text("")))
  let channel = open(@fixture.utf16_0()).unwrap().channels()[1]
  let c = { ..channel, byte_offset: 1, bit_count: 32, }
  assert_eq(raw_sample(b"XA\x00\x00\x00", c, 5), Text("A"))
}

///|
test "UTF16 malformed pairs field shape and bounds return existing source errors" {
  for
    payload in [b"\x00\xd8", b"\x00\xdc", b"\x00\xd8A\x00", b"\x00\xd8\x00\x00"] {
    assert_eq(
      utf16_field(8, payload),
      Err(CorruptedBlock("invalid UTF-16 sample")),
    )
  }
  for
    payload in [b"\xd8\x00", b"\xdc\x00", b"\xd8\x00\x00A", b"\xd8\x00\x00\x00"] {
    assert_eq(
      utf16_field(9, payload),
      Err(CorruptedBlock("invalid UTF-16 sample")),
    )
  }
  assert_eq(utf16_field(8, b"A\x00Z"), Err(InvalidBitField))
  assert_eq(utf16_field(9, b"\x00AZ"), Err(InvalidBitField))
  let channel = open(@fixture.utf16_0()).unwrap().channels()[1]
  let shifted = { ..channel, byte_offset: 0, bit_offset: 1, bit_count: 16, }
  assert_true(
    (Ok(raw_sample(b"A\x00", shifted, 2)) catch { e => Err(e) })
    is Err(InvalidBitField),
  )
  let outside = { ..channel, byte_offset: 0, bit_count: 32, }
  assert_true(
    (Ok(raw_sample(b"A\x00", outside, 2)) catch { e => Err(e) })
    is Err(CorruptedBlock(_)),
  )
  assert_true(utf16_field(17, b"A\x00") is Err(UnsupportedFeature(_)))
}

///|
test "UTF16 invalid samples are decoded and selected-record failures stay local" {
  let original = @fixture.utf16_0()
  let bytes = original.to_array()
  // The independent fixture has DT at928,data at952,stride45,LE offset8.
  let bad = 952 + 45 + 8
  bytes[bad] = b'\x00'
  bytes[bad + 1] = b'\xd8'
  bytes[bad + 2] = b'\x00'
  bytes[bad + 3] = b'\x00'
  let file = open(Bytes::from_array(bytes)).unwrap()
  assert_true(file.read_raw(1) is Err(CorruptedBlock("invalid UTF-16 sample")))
  assert_true(
    file.read_channel(1) is Err(CorruptedBlock("invalid UTF-16 sample")),
  )
  assert_eq(file.read_window(1, 0, 1).unwrap().raw, [Text("A")])
  assert_true(
    file.read_window(1, 1, 1)
    is Err(Source(CorruptedBlock("invalid UTF-16 sample"))),
  )
  // The BE field and the source byte constant are independent of that mutation.
  assert_eq(file.read_channel(2).unwrap().values[1], Label("龙🧪"))
  assert_eq(
    open(original).unwrap().read_channel(1).unwrap().values[1],
    Label("龙🧪"),
  )
}
