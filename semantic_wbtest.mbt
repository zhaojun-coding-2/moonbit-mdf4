///|
test "formula decimals use the nearest binary64 value" {
  assert_eq(convert(Formula("0.29"), Real(0.0)), Ok(Number(0.29)))
}

///|
test "formula subnormal literals survive exponent scaling" {
  assert_eq(convert(Formula("5e-324"), Real(0.0)), Ok(Number(5.0e-324)))
}

///|
test "formula rescaled mantissas do not overflow before exponent application" {
  assert_eq(
    convert(
      Formula(
        "1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e-309",
      ),
      Real(0.0),
    ),
    Ok(Number(1.0)),
  )
}

///|
test "singleton CC4 reports NaN input as a domain error" {
  assert_true(
    convert(Interpolated([0.0], [1.0]), Real(0.0 / 0.0))
    is Err(InvalidFormula(_)),
  )
}

///|
fn semantic_put(
  a : Array[Byte],
  pos : Int32,
  value : UInt64,
  width : Int32,
) -> Unit {
  for i in 0..<width {
    a[pos + i] = ((value >> (8 * i)) & 255UL).to_byte()
  }
}

///|
fn semantic_text_fixture(
  data_type : Int32,
  payload : Bytes,
) -> Bytes raise MdfError {
  let source = @fixture.core_0()
  let m = open(source).unwrap()
  let c = m.channels()[m.find_channel("identity").unwrap()]
  let cn = block(source, c.address)
  let dg = block(source, block(source, 64UL).links[0])
  let cg = block(source, dg.links[1])
  let dt = block(source, dg.links[2])
  let stride = uint_le(source, cg.data + 24, 4).to_int() +
    uint_le(source, cg.data + 28, 4).to_int()
  let a = source.to_array()
  a[cn.data + 2] = data_type.to_byte()
  semantic_put(a, cn.data + 8, (payload.length() * 8).to_uint64(), 4)
  for i in 0..<6 {
    for j, byte in payload {
      a[dt.data + i * stride + c.byte_offset + j] = byte
    }
  }
  Bytes::from_array(a)
}

///|
test "fixed text encodings and byte payloads preserve their distinct semantics" {
  let m = open(semantic_text_fixture(6, b"\xe9\xff\x00Z")).unwrap()
  let index = m.find_channel("identity").unwrap()
  assert_eq(m.read_raw(index).unwrap()[0], Text("éÿ"))
  assert_eq(m.read_channel(index).unwrap().values[0], Label("éÿ"))
  assert_eq(m.read_channel(index).unwrap().valid, [
    true, true, false, true, true, true,
  ])
  let m = open(semantic_text_fixture(7, b"\xc3\xa9\x00\xff")).unwrap()
  assert_eq(m.extract_channel("identity").unwrap().values[0], Label("é"))
  let m = open(semantic_text_fixture(10, b"A\x00\xffZ")).unwrap()
  let index = m.find_channel("identity").unwrap()
  assert_eq(m.read_raw(index).unwrap()[0], Octets(b"A\x00\xffZ"))
  assert_eq(m.read_channel(index).unwrap().values[0], Data(b"A\x00\xffZ"))
  let m = open(semantic_text_fixture(7, b"\xc0\xaf\x00Z")).unwrap()
  assert_true(m.extract_channel("identity") is Err(CorruptedBlock(_)))
}

///|
test "time master errors remain explicit through channel extraction" {
  let source = @fixture.core_0()
  let original = open(source).unwrap()
  let index = original.find_channel("identity").unwrap()
  let master = block(source, original.channels()[0].address)
  // This fixture's first channel is its unique time master.
  assert_eq(original.channels()[0].kind, 2)
  let a = source.to_array()
  a[master.data] = b'\x00'
  assert_true(
    open(Bytes::from_array(a)).unwrap().read_channel(index)
    is Err(InvalidTime("no time master")),
  )
  let a = source.to_array()
  let c = block(source, original.channels()[index].address)
  a[c.data] = b'\x02'
  a[c.data + 1] = b'\x01'
  assert_true(
    open(Bytes::from_array(a)).unwrap().read_channel(index)
    is Err(InvalidTime("multiple time masters")),
  )
  let a = source.to_array()
  semantic_put(a, master.data + 12, 1UL, 4)
  assert_true(
    open(Bytes::from_array(a)).unwrap().read_channel(index)
    is Err(InvalidTime("invalid master sample")),
  )
  let a = source.to_array()
  a[master.data + 2] = b'\x06'
  assert_true(
    open(Bytes::from_array(a)).unwrap().read_channel(index)
    is Err(InvalidTime("non-numeric master")),
  )
}

///|
test "decimal lexer and expression limits stay restricted" {
  for
    text in [
      ".", "1e", "1e+", "1e-", "1_0", "NaN", "inf", "1e1001", "1e-1001", "1e309",
      "0.2.9",
    ] {
    assert_true(convert(Formula(text), Real(0.0)) is Err(InvalidFormula(_)))
  }
  assert_eq(convert(Formula(".5 + 1. + 1E+2"), Real(0.0)), Ok(Number(101.5)))
  assert_eq(convert(Formula("0e1000"), Real(0.0)), Ok(Number(0.0)))
  assert_eq(convert(Formula("1e-1000"), Real(0.0)), Ok(Number(0.0)))
  assert_eq(convert(Interpolated([0.0], [1.0]), Real(2.0)), Ok(Number(1.0)))
  assert_true(
    convert(Interpolated([0.0, 1.0], [1.0, 2.0]), Real(0.0 / 0.0))
    is Err(InvalidFormula(_)),
  )
}
