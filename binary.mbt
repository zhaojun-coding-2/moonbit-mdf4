///|
fn span(bytes : Bytes, p : Int32, n : Int32) -> Unit raise MdfError {
  if p < 0 || n < 0 || p > bytes.length() || n > bytes.length() - p {
    corrupt("truncated span at \{p}, size \{n}")
  }
}

///|
fn u8(b : Bytes, p : Int32) -> Int32 raise MdfError {
  span(b, p, 1)
  b[p].to_int()
}

///|
fn uint_le(b : Bytes, p : Int32, n : Int32) -> UInt64 raise MdfError {
  span(b, p, n)
  let mut v = 0UL
  for i in 0..<n {
    v = v | (b[p + i].to_uint64() << (8 * i))
  }
  v
}

///|
fn uint_be(b : Bytes, p : Int32, n : Int32) -> UInt64 raise MdfError {
  span(b, p, n)
  let mut v = 0UL
  for i in 0..<n {
    v = (v << 8) | b[p + i].to_uint64()
  }
  v
}

///|
fn small(v : UInt64, max : Int32, what : String) -> Int32 raise MdfError {
  if v > max.to_uint64() {
    raise LimitExceeded(what)
  }
  v.to_int()
}

///|
fn copy_bytes(b : Bytes, p : Int32, n : Int32) -> Bytes raise MdfError {
  span(b, p, n)
  b[p:p + n].to_owned()
}

///|
fn f64(b : Bytes, p : Int32) -> Double raise MdfError {
  uint_le(b, p, 8).reinterpret_as_double()
}

///|
priv struct Block {
  id : String
  links : Array[UInt64]
  data : Int32
  length : Int32
}

///|
fn block(b : Bytes, address : UInt64) -> Block raise MdfError {
  let p = small(address, b.length(), "block address outside input")
  span(b, p, 24)
  if b[p] != b'#' || b[p + 1] != b'#' {
    corrupt("missing block marker at \{p}")
  }
  let length = small(
    uint_le(b, p + 8, 8),
    b.length() - p,
    "block length outside input",
  )
  if length < 24 {
    corrupt("block length below header size")
  }
  let count = small(
    uint_le(b, p + 16, 8),
    (length - 24) / 8,
    "invalid link count",
  )
  let id = String::from_array([
    b[p + 2].to_int().unsafe_to_char(),
    b[p + 3].to_int().unsafe_to_char(),
  ])
  {
    id,
    links: Array::makei(count, i => uint_le(b, p + 24 + 8 * i, 8)),
    data: p + 24 + 8 * count,
    length: length - 24 - 8 * count,
  }
}

///|
fn expect(
  b : Block,
  id : String,
  min_links : Int32,
  min_data : Int32,
) -> Unit raise MdfError {
  if b.id != id || b.links.length() < min_links || b.length < min_data {
    corrupt("expected \{id} links>=\{min_links} data>=\{min_data}, got \{b.id}")
  }
}

///|
fn tx(bytes : Bytes, address : UInt64) -> String raise MdfError {
  if address == 0UL {
    return ""
  }
  let t = block(bytes, address)
  if t.id != "TX" && t.id != "MD" {
    corrupt("expected TX/MD text")
  }
  let mut n = 0
  while n < t.length && bytes[t.data + n] != b'\x00' {
    n += 1
  }
  @utf8.decode(bytes[t.data:t.data + n]) catch {
    _ => raise CorruptedBlock("invalid UTF-8 text")
  }
}

///|
/// Extract a field using MDF integer offset semantics. Raw bytes remain exact.
#warnings("-result_error_return")
pub fn extract_integer(
  bytes : Bytes,
  byte_offset : Int32,
  bit_offset : Int32,
  bit_count : Int32,
  big_endian : Bool,
  signed : Bool,
) -> Result[RawValue, MdfError] {
  Ok(
    integer_checked(
      bytes, byte_offset, bit_offset, bit_count, big_endian, signed,
    ),
  ) catch {
    e => Err(e)
  }
}

///|
fn integer_checked(
  b : Bytes,
  p : Int32,
  bit : Int32,
  width : Int32,
  be : Bool,
  signed : Bool,
) -> RawValue raise MdfError {
  if bit < 0 || bit > 7 || width < 1 || width > 64 {
    raise InvalidBitField
  }
  let n = (width + bit + 7) / 8
  span(b, p, n)
  let mut raw = 0UL
  // A 64-bit non-aligned field can occupy nine bytes: never load it into a single word first.
  for k in 0..<width {
    let source = bit + k
    let byte = if be { p + n - 1 - source / 8 } else { p + source / 8 }
    if (b[byte].to_int() & (1 << (source % 8))) != 0 {
      raw = raw | (1UL << k)
    }
  }
  if !signed {
    return Unsigned(raw)
  }
  if width < 64 && (raw & (1UL << (width - 1))) != 0 {
    raw = raw | (0xFFFFFFFFFFFFFFFFUL << width)
  }
  Signed(raw.reinterpret_as_int64())
}
