///|
fn inflate_zlib(input : Bytes, length : Int32) -> Bytes raise MdfError {
  let src = @io.Buffer::from_bytes(input)
  let (reader, err) = @zlib.Reader::new(src)
  if err != None {
    corrupt("DZ zlib header failure")
  }
  let output = @io.Slice::new(Array::make(length, b'\x00'))
  let mut pos = 0
  while pos < length {
    let (n, e) = @io.Reader::read(reader, output[pos:])
    if n < 0 || n > length - pos {
      corrupt("invalid decompressor read count")
    }
    pos += n
    if e != None && e != Some(@io.eof) {
      corrupt("DZ zlib data/checksum failure")
    }
    if e == Some(@io.eof) {
      break
    }
    if n == 0 {
      corrupt("DZ decompressor made no progress")
    }
  }
  let (n, e) = @io.Reader::read(reader, @io.Slice::new([b'\x00']))
  let close_err = @io.Closer::close(reader)
  if pos != length || n != 0 || e != Some(@io.eof) || close_err != None {
    corrupt("DZ original length/checksum mismatch")
  }
  output.to_bytes()
}

///|
/// Reverse the byte transpose while retaining an incomplete final row.
#warnings("-result_error_return")
pub fn inverse_transpose(
  bytes : Bytes,
  columns : Int32,
) -> Result[Bytes, MdfError] {
  Ok(transpose_checked(bytes, columns)) catch {
    e => Err(e)
  }
}

///|
fn transpose_checked(b : Bytes, cols : Int32) -> Bytes raise MdfError {
  if cols <= 0 {
    corrupt("zero transpose parameter")
  }
  let rows = b.length() / cols
  let full = rows * cols
  let a = b.to_array()
  for r in 0..<rows {
    for c in 0..<cols {
      a[r * cols + c] = b[c * rows + r]
    }
  }
  // a[full..] already contains the untransposed remainder.
  if full > b.length() {
    corrupt("transpose overflow")
  }
  Bytes::from_array(a)
}

///|
fn collect_data(
  bytes : Bytes,
  address : UInt64,
  out : Array[Byte],
  seen : Array[UInt64],
  limits : Limits,
) -> Unit raise MdfError {
  if address == 0UL {
    return
  }
  if seen.contains(address) {
    corrupt("cyclic/reused data block")
  }
  if seen.length() >= limits.max_blocks {
    raise LimitExceeded("data block count")
  }
  seen.push(address)
  let b = block(bytes, address)
  match b.id {
    "DT" => {
      if b.length > limits.max_output - out.length() {
        raise LimitExceeded("uncompressed data")
      }
      for v in bytes[b.data:b.data + b.length] {
        out.push(v)
      }
    }
    "DZ" => {
      expect(b, "DZ", 0, 24)
      if u8(bytes, b.data) != 68 || u8(bytes, b.data + 1) != 84 {
        raise UnsupportedFeature("DZ does not contain DT")
      }
      let mode = u8(bytes, b.data + 2)
      if mode > 1 {
        raise UnsupportedFeature("DZ compression type \{mode}")
      }
      let n = small(
        uint_le(bytes, b.data + 8, 8),
        limits.max_output - out.length(),
        "DZ output size",
      )
      let z = small(
        uint_le(bytes, b.data + 16, 8),
        b.length - 24,
        "DZ compressed length",
      )
      if z != b.length - 24 {
        corrupt("DZ length mismatch")
      }
      let raw = inflate_zlib(copy_bytes(bytes, b.data + 24, z), n)
      let raw = if mode == 1 {
        transpose_checked(
          raw,
          small(
            uint_le(bytes, b.data + 4, 4),
            limits.max_output,
            "DZ transpose parameter",
          ),
        )
      } else {
        raw
      }
      for v in raw {
        out.push(v)
      }
    }
    "HL" => {
      expect(b, "HL", 1, 8)
      if b.links[0] == 0UL {
        corrupt("HL lacks DL")
      }
      let dl = block(bytes, b.links[0])
      expect(dl, "DL", 1, 8)
      collect_data(bytes, b.links[0], out, seen, limits)
    }
    "DL" => {
      expect(b, "DL", 1, 8)
      let count = small(
        uint_le(bytes, b.data + 4, 4),
        b.links.length() - 1,
        "DL count",
      )
      if count != b.links.length() - 1 {
        corrupt("DL link count mismatch")
      }
      let equal = (u8(bytes, b.data) & 1) != 0
      let need = if equal { 16 } else { 8 + 8 * count }
      if b.length < need {
        corrupt("truncated DL offsets")
      }
      let fixed = if equal { uint_le(bytes, b.data + 8, 8) } else { 0UL }
      for i in 0..<count {
        if !equal &&
          uint_le(bytes, b.data + 8 + 8 * i, 8) != out.length().to_uint64() {
          corrupt("DL logical offset mismatch")
        }
        let before = out.length()
        if b.links[i + 1] == 0UL {
          corrupt("null DL child")
        }
        let child = block(bytes, b.links[i + 1])
        if child.id != "DT" && child.id != "DZ" {
          corrupt("DL child must be DT/DZ")
        }
        collect_data(bytes, b.links[i + 1], out, seen, limits)
        let size = (out.length() - before).to_uint64()
        if equal && (size > fixed || (i < count - 1 && size != fixed)) {
          corrupt("DL equal length mismatch")
        }
      }
      collect_data(bytes, b.links[0], out, seen, limits)
    }
    _ => raise UnsupportedFeature("data block \{b.id}")
  }
}
