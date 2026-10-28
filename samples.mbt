///|
fn MdfFile::channel_at(self : MdfFile, index : Int32) -> Channel raise MdfError {
  if index < 0 || index >= self.channels_.length() {
    raise ChannelNotFound(index.to_string())
  }
  self.channels_[index]
}

///|
#warnings("-result_error_return")
pub fn MdfFile::find_channel(
  self : MdfFile,
  name : String,
) -> Result[Int32, MdfError] {
  let mut found = -1
  for i, c in self.channels_ {
    if c.name == name {
      if found >= 0 {
        return Err(AmbiguousChannel(name))
      }
      found = i
    }
  }
  if found < 0 {
    Err(ChannelNotFound(name))
  } else {
    Ok(found)
  }
}

///|
fn raw_sample(
  record : Bytes,
  c : Channel,
  size : Int32,
) -> RawValue raise MdfError {
  if c.kind != 0 && c.kind != 2 {
    raise UnsupportedFeature("channel kind \{c.kind}")
  }
  if c.bit_offset < 0 || c.bit_offset > 7 {
    raise InvalidBitField
  }
  let data = copy_bytes(record, 0, size)
  match c.data_type {
    0 | 1 | 2 | 3 =>
      integer_checked(
        data,
        c.byte_offset,
        c.bit_offset,
        c.bit_count,
        c.data_type % 2 == 1,
        c.data_type >= 2,
      )
    4 | 5 => {
      if c.bit_offset != 0 || (c.bit_count != 32 && c.bit_count != 64) {
        raise InvalidBitField
      }
      let n = c.bit_count / 8
      let u = if c.data_type == 5 {
        uint_be(data, c.byte_offset, n)
      } else {
        uint_le(data, c.byte_offset, n)
      }
      Real(
        if n == 8 {
          u.reinterpret_as_double()
        } else {
          Float::reinterpret_from_uint(u.to_uint()).to_double()
        },
      )
    }
    6 | 7 | 10 => {
      if c.bit_offset != 0 || c.bit_count % 8 != 0 {
        raise InvalidBitField
      }
      let b = copy_bytes(data, c.byte_offset, c.bit_count / 8)
      if c.data_type == 10 {
        return Octets(b)
      }
      let mut n = 0
      while n < b.length() && b[n] != b'\x00' {
        n += 1
      }
      if c.data_type == 7 {
        Text(
          @utf8.decode(b[0:n]) catch {
            _ => raise CorruptedBlock("invalid UTF-8 sample")
          },
        )
      } else {
        let chars : Array[Char] = []
        for i in 0..<n {
          chars.push(b[i].to_int().unsafe_to_char())
        }
        Text(String::from_array(chars))
      }
    }
    _ => raise UnsupportedFeature("sample data type \{c.data_type}")
  }
}

///|
fn valid_sample(record : Bytes, c : Channel, g : Group) -> Bool raise MdfError {
  if (c.flags & 1U) != 0U {
    return false
  }
  if (c.flags & 2U) == 0U {
    return true
  }
  if c.invalid_bit < 0 || c.invalid_bit / 8 >= g.invalid_bytes {
    corrupt("invalidation bit outside record")
  }
  (u8(record, g.size + c.invalid_bit / 8) & (1 << (c.invalid_bit % 8))) == 0
}

///|
#warnings("-result_error_return")
pub fn MdfFile::read_raw(
  self : MdfFile,
  index : Int32,
) -> Result[Array[RawValue], MdfError] {
  try {
    let c = self.channel_at(index)
    let g = self.groups[c.group]
    let a : Array[RawValue] = []
    for r in g.records {
      a.push(raw_sample(r, c, g.size))
    }
    Ok(a)
  } catch {
    e => Err(e)
  }
}

///|
fn MdfFile::series_checked(
  self : MdfFile,
  index : Int32,
) -> Series raise MdfError {
  let c = self.channel_at(index)
  let g = self.groups[c.group]
  let mut master : Channel? = None
  for candidate in self.channels_ {
    if candidate.group == c.group && candidate.kind == 2 && candidate.sync == 1 {
      if master is Some(_) {
        raise InvalidTime("multiple time masters")
      }
      master = Some(candidate)
    }
  }
  let m = match master {
    Some(v) => v
    None => raise InvalidTime("no time master")
  }
  let conv = read_conversion(self.bytes, c.conversion_address, 0)
  let mconv = read_conversion(self.bytes, m.conversion_address, 0)
  let values : Array[Value] = []
  let times : Array[Double] = []
  let valid : Array[Bool] = []
  for r in g.records {
    let t = match convert_checked(mconv, raw_sample(r, m, g.size)) {
      Number(t) => t
      _ => raise InvalidTime("non-numeric master")
    }
    if !finite(t) || !valid_sample(r, m, g) {
      raise InvalidTime("invalid master sample")
    }
    times.push(t)
    let v = raw_sample(r, c, g.size)
    values.push(convert_checked(conv, v))
    valid.push(valid_sample(r, c, g))
  }
  { name: c.name, unit: c.unit, timestamps: times, values, valid, }
}

///|
#warnings("-result_error_return")
pub fn MdfFile::read_channel(
  self : MdfFile,
  index : Int32,
) -> Result[Series, MdfError] {
  Ok(self.series_checked(index)) catch {
    e => Err(e)
  }
}

///|
#warnings("-result_error_return")
pub fn MdfFile::extract_channel(
  self : MdfFile,
  name : String,
) -> Result[Series, MdfError] {
  match self.find_channel(name) {
    Err(e) => Err(e)
    Ok(i) => self.read_channel(i)
  }
}

///|
/// Explicit alignment. No extrapolation, sorting, dropping invalid rows or implicit policies.
#warnings("-result_error_return")
pub fn resample(
  series : Series,
  raster : Array[Double],
  policy : Interpolation,
) -> Result[Series, MdfError] {
  Ok(resample_checked(series, raster, policy)) catch {
    e => Err(e)
  }
}

///|
fn check_time(t : Array[Double]) -> Unit raise MdfError {
  for i, v in t {
    if !finite(v) || (i > 0 && v <= t[i - 1]) {
      raise InvalidTime("timestamps must be finite and strictly increasing")
    }
  }
}

///|
fn resample_checked(
  s : Series,
  raster : Array[Double],
  policy : Interpolation,
) -> Series raise MdfError {
  let n = s.timestamps.length()
  if n != s.values.length() || n != s.valid.length() {
    raise InvalidTime("series shape mismatch")
  }
  check_time(s.timestamps)
  check_time(raster)
  if policy == Linear {
    for v in s.values {
      if !(v is Number(_)) {
        raise InvalidTime("linear interpolation requires numeric values")
      }
    }
  }
  let values : Array[Value] = []
  let valid : Array[Bool] = []
  let mut i = 0
  for t in raster {
    if n == 0 || t < s.timestamps[0] || t > s.timestamps[n - 1] {
      values.push(Number(0.0 / 0.0))
      valid.push(false)
      continue
    }
    while i + 1 < n && s.timestamps[i + 1] <= t {
      i += 1
    }
    if policy == Previous || t == s.timestamps[i] {
      values.push(s.values[i])
      valid.push(s.valid[i])
    } else {
      let v = match (s.values[i], s.values[i + 1]) {
        (Number(a), Number(b)) =>
          Number(
            interpolate_finite(
              a,
              b,
              interpolation_fraction(s.timestamps[i], s.timestamps[i + 1], t),
            ),
          )
        _ => raise InvalidTime("non-numeric interpolation")
      }
      values.push(v)
      valid.push(s.valid[i] && s.valid[i + 1])
    }
  }
  { name: s.name, unit: s.unit, timestamps: raster.copy(), values, valid, }
}
