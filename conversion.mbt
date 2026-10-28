///|
pub(all) enum Conversion {
  Identity
  LinearScale(Double, Double)
  Rational(Array[Double])
  Formula(String)
  Interpolated(Array[Double], Array[Double])
  Enumeration(Array[Double], Array[String], String)
} derive(Debug)

///|
fn read_conversion(
  bytes : Bytes,
  address : UInt64,
  depth : Int32,
) -> Conversion raise MdfError {
  if address == 0UL {
    return Identity
  }
  if depth > 32 {
    raise LimitExceeded("CC reference depth")
  }
  let cc = block(bytes, address)
  expect(cc, "CC", 4, 24)
  let kind = u8(bytes, cc.data)
  let refs = uint_le(bytes, cc.data + 4, 2).to_int()
  let n = uint_le(bytes, cc.data + 6, 2).to_int()
  if n > (cc.length - 24) / 8 {
    corrupt("CC parameter count")
  }
  let params : Array[Double] = []
  for i in 0..<n {
    params.push(f64(bytes, cc.data + 24 + 8 * i))
  }
  match kind {
    0 => Identity
    1 => {
      if n != 2 {
        corrupt("linear CC requires two parameters")
      }
      LinearScale(params[1], params[0])
    }
    2 => {
      if n != 6 {
        corrupt("rational CC requires six parameters")
      }
      Rational(params)
    }
    3 => {
      if refs != 1 || cc.links.length() < 5 {
        corrupt("formula reference count")
      }
      Formula(tx(bytes, cc.links[4]))
    }
    4 => {
      if n < 2 || n % 2 != 0 {
        corrupt("interpolation CC pairs")
      }
      let x : Array[Double] = []
      let y : Array[Double] = []
      for i in 0..<(n / 2) {
        x.push(params[2 * i])
        y.push(params[2 * i + 1])
      }
      check_table(x, y.length())
      Interpolated(x, y)
    }
    7 => {
      if refs != n + 1 || cc.links.length() < 4 + refs {
        corrupt("enum CC reference count")
      }
      let labels : Array[String] = []
      for i in 0..<n {
        labels.push(tx(bytes, cc.links[4 + i]))
      }
      Enumeration(params, labels, tx(bytes, cc.links[4 + n]))
    }
    _ => raise UnsupportedConversion(kind)
  }
}

///|
fn check_table(x : Array[Double], n : Int32) -> Unit raise MdfError {
  if x.length() == 0 || x.length() != n {
    corrupt("table shape")
  }
  for i, v in x {
    if !finite(v) || (i > 0 && x[i - 1] >= v) {
      corrupt("table keys not strictly increasing")
    }
  }
}

///|
fn numeric(raw : RawValue) -> Double raise MdfError {
  match raw {
    Unsigned(v) => v.to_double()
    Signed(v) => v.to_double()
    Real(v) => v
    _ => raise UnsupportedFeature("conversion requires numeric input")
  }
}

///|
#warnings("-result_error_return")
pub fn convert(
  conversion : Conversion,
  raw : RawValue,
) -> Result[Value, MdfError] {
  Ok(convert_checked(conversion, raw)) catch {
    e => Err(e)
  }
}

///|
fn convert_checked(c : Conversion, raw : RawValue) -> Value raise MdfError {
  if c is Identity {
    return match raw {
      Octets(v) => Data(v)
      Text(v) => Label(v)
      _ => Number(numeric(raw))
    }
  }
  let x = numeric(raw)
  match c {
    Enumeration(keys, labels, default) => {
      if keys.length() != labels.length() {
        corrupt("enum shape")
      }
      for i, k in keys {
        if x == k {
          return Label(labels[i])
        }
      }
      Label(default)
    }
    _ => {
      let y = match c {
        Identity => x
        LinearScale(a, b) => linear_value(a, b, x)
        Rational(p) => {
          if p.length() != 6 {
            corrupt("rational parameter count")
          }
          rational_value(p, x)
        }
        Formula(f) => eval_formula(f, x)
        Interpolated(keys, values) => {
          check_table(keys, values.length())
          if x.is_nan() {
            raise InvalidFormula("NaN interpolation input")
          }
          let n = keys.length()
          if x <= keys[0] {
            values[0]
          } else if x >= keys[n - 1] {
            values[n - 1]
          } else {
            let mut i = 1
            while x > keys[i] {
              i += 1
            }
            interpolate_finite(
              values[i - 1],
              values[i],
              interpolation_fraction(keys[i - 1], keys[i], x),
            )
          }
        }
        Enumeration(_, _, _) => x
      }
      if !finite(y) {
        raise InvalidFormula("non-finite numeric conversion")
      }
      Number(y)
    }
  }
}
