///|
fn deep_put(
  a : Array[Byte],
  offset : Int32,
  value : UInt64,
  width : Int32,
) -> Unit {
  for j in 0..<width {
    a[offset + j] = ((value >> (8 * j)) & 255UL).to_byte()
  }
}

///|
test "wide interleaved record IDs preserve values and masks" {
  let source = @fixture.unsorted()
  let dg_addr = block(source, 64UL).links[0]
  let dg = block(source, dg_addr)
  let first = block(source, dg.links[1])
  let second = block(source, first.links[0])
  let dt = block(source, dg.links[2])
  for width in [2, 4, 8] {
    let ids = if width == 8 {
      [0x8000000000000001UL, 0xFFFFFFFFFFFFFFFFUL]
    } else if width == 4 {
      [0x80000001UL, 0xFFFFFFFFUL]
    } else {
      [0x8001UL, 0xFFFFUL]
    }
    let a = source.to_array()
    a[dg.data] = width.to_byte()
    deep_put(a, first.data, ids[0], 8)
    deep_put(a, second.data, ids[1], 8)
    while a.length() % 8 != 0 {
      a.push(b'\x00')
    }
    let start = a.length()
    for _ in 0..<24 {
      a.push(b'\x00')
    }
    for j, c in b"##DT" {
      a[start + j] = c
    }
    deep_put(a, dg_addr.to_int() + 40, start.to_uint64(), 8)
    let mut pos = dt.data
    while pos < dt.data + dt.length {
      let id = source[pos].to_uint64()
      let group = if id == uint_le(source, first.data, 8) {
        first
      } else {
        second
      }
      let replacement = if id == uint_le(source, first.data, 8) {
        ids[0]
      } else {
        ids[1]
      }
      for j in 0..<width {
        a.push(((replacement >> (8 * j)) & 255UL).to_byte())
      }
      let size = uint_le(source, group.data + 24, 4).to_int() +
        uint_le(source, group.data + 28, 4).to_int()
      for j in 0..<size {
        a.push(source[pos + 1 + j])
      }
      pos += 1 + size
    }
    deep_put(a, start + 8, (a.length() - start).to_uint64(), 8)
    let m = open(Bytes::from_array(a)).unwrap()
    let g0 = m.extract_channel("g0").unwrap()
    assert_eq(g0.values, [Number(-3.0), Number(6.0)])
    assert_eq(g0.valid, [true, false])
    assert_eq(m.extract_channel("g1").unwrap().values, [
      Number(42.0),
      Number(-99.0),
    ])
  }
}

///|
test "64-bit block spans and pre-inflate output budgets" {
  let source = @fixture.core_0()
  let dg_addr = block(source, 64UL).links[0]
  for offset in [88, dg_addr.to_int() + 8, dg_addr.to_int() + 16] {
    let a = source.to_array()
    deep_put(a, offset, 0xFFFFFFFFFFFFFFFFUL, 8)
    assert_true(open(Bytes::from_array(a)) is Err(LimitExceeded(_)))
  }
  let source = @fixture.core_1()
  let dg = block(source, block(source, 64UL).links[0])
  let mut addr = dg.links[2]
  let mut dz = block(source, addr)
  // Fixture uses HL -> DL -> DZ; traverse links without assuming file offsets.
  while dz.id != "DZ" {
    addr = if dz.id == "DL" { dz.links[1] } else { dz.links[0] }
    dz = block(source, addr)
  }
  let a = source.to_array()
  deep_put(a, dz.data + 8, 0xFFFFFFFFFFFFFFFFUL, 8)
  assert_true(open(Bytes::from_array(a)) is Err(LimitExceeded(_)))
}
