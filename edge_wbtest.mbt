///|
test "header corruption, limits, versions and unfinished file" {
  assert_true(open(b"MDF") is Err(CorruptedBlock(_)))
  let a = @fixture.core_0().to_array()
  for i, v in b"UnFinMF ".to_array() {
    a[i] = v
  }
  assert_true(open(Bytes::from_array(a)) is Err(UnfinalizedFile))
  let a = @fixture.core_0().to_array()
  a[10] = b'2'
  a[11] = b'0'
  assert_true(open(Bytes::from_array(a)) is Err(UnsupportedVersion("4.20")))
  let a = @fixture.core_0().to_array()
  a[60] = b'\x01'
  assert_true(open(Bytes::from_array(a)) is Err(UnfinalizedFile))
  assert_true(
    open(@fixture.core_0(), limits={
      max_output: 10,
      max_blocks: 1000,
      max_samples: 100,
    })
    is Err(LimitExceeded(_)),
  )
  assert_true(
    open(@fixture.core_0(), limits={
      max_output: 100000,
      max_blocks: 1,
      max_samples: 100,
    })
    is Err(LimitExceeded(_)),
  )
}

///|
test "cyclic links and truncated records are rejected" {
  let a = @fixture.core_0().to_array()
  let dg = uint_le(@fixture.core_0(), 88, 8).to_int()
  for j in 0..<8 {
    a[dg + 24 + j] = ((dg.to_uint64() >> (8 * j)) & 255UL).to_byte()
  }
  assert_true(open(Bytes::from_array(a)) is Err(CorruptedBlock(_)))
  let b = @fixture.core_0()
  let cut = b[0:b.length() / 2].to_owned()
  assert_true(open(cut) is Err(_))
}

///|
test "MDF bit boundaries and ninth byte" {
  assert_eq(
    extract_integer(b"\x00\x80", 0, 7, 2, false, false),
    Ok(Unsigned(0UL)),
  )
  assert_eq(
    extract_integer(b"\x80\x01", 0, 7, 2, false, false),
    Ok(Unsigned(3UL)),
  )
  assert_eq(
    extract_integer(b"\x01\x80", 0, 7, 2, true, false),
    Ok(Unsigned(3UL)),
  )
  assert_eq(extract_integer(b"\xff", 0, 0, 7, false, true), Ok(Signed(-1L)))
  assert_eq(
    extract_integer(
      b"\xff\xff\xff\xff\xff\xff\xff\xff\x7f", 0, 7, 64, false, false,
    ),
    Ok(Unsigned(0xFFFFFFFFFFFFFFFFUL)),
  )
  assert_eq(
    extract_integer(
      b"\x7f\xff\xff\xff\xff\xff\xff\xff\xff", 0, 7, 64, true, false,
    ),
    Ok(Unsigned(0xFFFFFFFFFFFFFFFFUL)),
  )
  assert_true(
    extract_integer(b"\x00", 0, 0, 64, false, false) is Err(CorruptedBlock(_)),
  )
  assert_eq(
    extract_integer(b"\x00", 0, 8, 1, false, false),
    Err(InvalidBitField),
  )
  let c : Channel = {
    name: "IEEE vector",
    unit: "",
    group: 0,
    address: 0UL,
    kind: 0,
    sync: 0,
    data_type: 5,
    byte_offset: 0,
    bit_offset: 0,
    bit_count: 32,
    flags: 0U,
    invalid_bit: 0,
    conversion_address: 0UL,
  }
  assert_eq(raw_sample(b"\x3f\x80\x00\x00", c, 4), Real(1.0))
  let c = { ..c, data_type: 4, }
  assert_eq(raw_sample(b"\x00\x00\x80\x3f", c, 4), Real(1.0))
  let c = { ..c, data_type: 5, bit_count: 64, }
  assert_eq(raw_sample(b"\xbf\xf0\x00\x00\x00\x00\x00\x00", c, 8), Real(-1.0))
}

///|
test "formula precedence, syntax, mathematical domains and unsafe text" {
  assert_eq(convert(Formula("-2^2+2**3**2"), Real(0.0)), Ok(Number(508.0)))
  assert_eq(
    convert(Formula("max(abs(-X1),3)+sqrt(4)+log(e)"), Real(2.0)),
    Ok(Number(6.0)),
  )
  assert_true(convert(Formula("1 2"), Real(0.0)) is Err(InvalidFormula(_)))
  assert_true(convert(Formula("X+"), Real(0.0)) is Err(InvalidFormula(_)))
  assert_true(convert(Formula("sqrt(-1)"), Real(0.0)) is Err(InvalidFormula(_)))
  assert_true(
    convert(Formula("system(1)"), Real(0.0)) is Err(InvalidFormula(_)),
  )
  assert_true(
    convert(Rational([1.0, 0.0, 0.0, 0.0, 0.0, 0.0]), Real(1.0))
    is Err(InvalidFormula(_)),
  )
  assert_true(
    convert(Interpolated([1.0, 1.0], [1.0, 2.0]), Real(1.0))
    is Err(CorruptedBlock(_)),
  )
  assert_eq(
    convert(Enumeration([1.0], ["On"], "Other"), Unsigned(2UL)),
    Ok(Label("Other")),
  )
}

///|
test "transpose remainder and bad compressed stream" {
  assert_eq(
    inverse_transpose(b"\x00\x03\x06\x01\x04\x07\x02\x05\x08\xff", 3),
    Ok(b"\x00\x01\x02\x03\x04\x05\x06\x07\x08\xff"),
  )
  assert_true(inverse_transpose(b"", 0) is Err(CorruptedBlock(_)))
  let b = @fixture.core_1()
  let a = b.to_array()
  let mut i = 64
  let mut found = false
  while i < b.length() - 4 {
    if b[i:i + 4] == b"##DZ" {
      let dz = block(b, i.to_uint64())
      a[dz.data + 24] = b'\x00'
      found = true
      break
    }
    i += 1
  }
  assert_true(found)
  assert_true(open(Bytes::from_array(a)) is Err(CorruptedBlock(_)))
}

///|
test "explicit time alignment retains gaps and enum policy" {
  let s : Series = {
    name: "a",
    unit: "u",
    timestamps: [0.0, 1.0, 2.0],
    values: [Number(0.0), Number(10.0), Number(20.0)],
    valid: [true, false, true],
  }
  let aligned = resample(s, [-1.0, 0.0, 0.5, 1.0, 1.5, 2.0, 3.0], Linear).unwrap()
  assert_eq(aligned.valid, [false, true, false, false, false, true, false])
  assert_eq(aligned.values[2], Number(5.0))
  assert_eq(resample(s, [0.5], Previous).unwrap().values, [Number(0.0)])
  assert_true(resample(s, [1.0, 1.0], Previous) is Err(InvalidTime(_)))
  let s : Series = {
    name: "e",
    unit: "",
    timestamps: [0.0, 1.0],
    values: [Label("Off"), Label("On")],
    valid: [true, true],
  }
  assert_true(resample(s, [0.5], Linear) is Err(InvalidTime(_)))
  assert_eq(resample(s, [0.5], Previous).unwrap().values, [Label("Off")])
  let empty : Series = {
    name: "empty",
    unit: "",
    timestamps: [],
    values: [],
    valid: [],
  }
  assert_eq(resample(empty, [0.0], Previous).unwrap().valid, [false])
}

///|
test "interleaved record IDs, invalidity and ambiguous channel names" {
  let m = open(@fixture.unsorted()).unwrap()
  let a = m.extract_channel("g0").unwrap()
  let b = m.extract_channel("g1").unwrap()
  assert_eq(a.values, [Number(-3.0), Number(6.0)])
  assert_eq(a.timestamps, [0.0, 1.0])
  assert_eq(a.valid, [true, false])
  assert_eq(b.values, [Number(42.0), Number(-99.0)])
  assert_eq(b.timestamps, [0.25, 0.75])
  assert_eq(b.valid, [true, true])
  let raster = [0.0, 0.25, 0.5, 0.75, 1.0]
  let aa = resample(a, raster, Previous).unwrap()
  let bb = resample(b, raster, Previous).unwrap()
  assert_eq(aa.timestamps, bb.timestamps)
  assert_eq(aa.valid, [true, true, true, true, false])
  assert_eq(bb.valid, [false, true, true, true, false])
  assert_eq(bb.values[2], Number(42.0))
  assert_true(m.find_channel("time") is Err(AmbiguousChannel("time")))
  assert_true(m.find_channel("missing") is Err(ChannelNotFound("missing")))
  assert_true(m.read_raw(-1) is Err(ChannelNotFound(_)))
  let bytes = @fixture.unsorted()
  let a = bytes.to_array()
  let dg = block(bytes, block(bytes, 64UL).links[0])
  let raw_addr = dg.links[2]
  let raw = block(bytes, raw_addr)
  a[raw.data] = b'\x55'
  assert_true(open(Bytes::from_array(a)) is Err(CorruptedBlock(_)))
}

///|
test "unsupported conversion preserves explicit raw access" {
  let bytes = @fixture.core_0()
  let m = open(bytes).unwrap()
  let index = m.find_channel("linear").unwrap()
  let cc = block(bytes, m.channels()[index].conversion_address)
  let a = bytes.to_array()
  a[cc.data] = b'\x05'
  let changed = open(Bytes::from_array(a)).unwrap()
  assert_true(
    changed.extract_channel("linear") is Err(UnsupportedConversion(5)),
  )
  assert_eq(changed.read_raw(index).unwrap()[1], Unsigned(1UL))
  let a = bytes.to_array()
  let cn = block(bytes, m.channels()[index].address)
  a[cn.data + 12] = b'\x01'
  // Ignored invalid-bit position can contain the sentinel 0xffffffff.
  for i in 0..<4 {
    a[cn.data + 16 + i] = b'\xff'
  }
  let invalid = open(Bytes::from_array(a)).unwrap()
  assert_eq(invalid.extract_channel("linear").unwrap().valid, [
    false, false, false, false, false, false,
  ])
}
