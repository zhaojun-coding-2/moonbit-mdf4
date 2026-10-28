///|
// Every finite binary64 input is exactly an integer times a power of two.
// Polynomial terms use this private representation so neither exponent range
// nor cancellation can turn a nonzero rational denominator into zero.
fn dyadic_value(v : Double) -> (@bigint.BigInt, Int32) {
  let bits = v.reinterpret_as_uint64()
  let exponent = ((bits >> 52) & 2047UL).to_int()
  let fraction = bits & 0x000FFFFFFFFFFFFFUL
  let mantissa = @bigint.BigInt::from_uint64(
    if exponent == 0 {
      fraction
    } else {
      fraction | 0x0010000000000000UL
    },
  )
  (
    if bits >> 63 != 0UL {
      -mantissa
    } else {
      mantissa
    },
    if exponent == 0 {
      -1074
    } else {
      exponent - 1075
    },
  )
}

///|
fn dyadic_product(
  a : (@bigint.BigInt, Int32),
  b : (@bigint.BigInt, Int32),
) -> (@bigint.BigInt, Int32) {
  (a.0 * b.0, a.1 + b.1)
}

///|
fn dyadic_sum(
  a : (@bigint.BigInt, Int32),
  b : (@bigint.BigInt, Int32),
) -> (@bigint.BigInt, Int32) {
  if a.0.is_zero() {
    return b
  }
  if b.0.is_zero() {
    return a
  }
  let exponent = if a.1 < b.1 { a.1 } else { b.1 }
  ((a.0 << (a.1 - exponent)) + (b.0 << (b.1 - exponent)), exponent)
}

///|
fn dyadic_polynomial(
  a : Double,
  b : Double,
  c : Double,
  x : Double,
) -> (@bigint.BigInt, Int32) {
  let sx = dyadic_value(x)
  dyadic_sum(
    dyadic_sum(
      dyadic_product(dyadic_product(dyadic_value(a), sx), sx),
      dyadic_product(dyadic_value(b), sx),
    ),
    dyadic_value(c),
  )
}

///|
// Round the exact quotient to nearest binary64, ties to even. The quotient's
// integer significand is at most 53 bits; its conversion to Double is exact.
fn dyadic_quotient(
  n : (@bigint.BigInt, Int32),
  d : (@bigint.BigInt, Int32),
) -> Double raise MdfError {
  if d.0.is_zero() {
    raise InvalidFormula("rational denominator zero")
  }
  let negative = (n.0.compare_int(0) < 0) != (d.0.compare_int(0) < 0)
  let mut numerator = if n.0.compare_int(0) < 0 { -n.0 } else { n.0 }
  let mut denominator = if d.0.compare_int(0) < 0 { -d.0 } else { d.0 }
  if numerator.is_zero() {
    return 0.0
  }
  let mut exponent = numerator.bit_length() - denominator.bit_length()
  let below = if exponent >= 0 {
    numerator < denominator << exponent
  } else {
    numerator << -exponent < denominator
  }
  if below {
    exponent -= 1
  }
  exponent += n.1 - d.1
  if exponent > 1023 {
    return if negative { -1.0 / 0.0 } else { 1.0 / 0.0 }
  }
  if exponent < -1075 {
    return if negative { -0.0 } else { 0.0 }
  }
  let quantum = if exponent - 52 < -1074 { -1074 } else { exponent - 52 }
  let shift = n.1 - d.1 - quantum
  if shift >= 0 {
    numerator = numerator << shift
  } else {
    denominator = denominator << -shift
  }
  let mut significand = numerator / denominator
  let remainder_twice = (numerator % denominator) << 1
  if remainder_twice > denominator ||
    (remainder_twice == denominator && (significand.to_uint64() & 1UL) != 0UL) {
    significand = significand + @bigint.BigInt::from_int(1)
  }
  let value = @math.scalbn(significand.to_uint64().to_double(), quantum)
  if negative {
    -value
  } else {
    value
  }
}

///|
fn rational_value(p : Array[Double], x : Double) -> Double raise MdfError {
  if !finite(x) {
    raise InvalidFormula("non-finite numeric conversion")
  }
  for coefficient in p {
    if !finite(coefficient) {
      raise InvalidFormula("non-finite numeric conversion")
    }
  }
  dyadic_quotient(
    dyadic_polynomial(p[0], p[1], p[2], x),
    dyadic_polynomial(p[3], p[4], p[5], x),
  )
}

///|
fn linear_value(a : Double, b : Double, x : Double) -> Double raise MdfError {
  let y = a * x + b
  if finite(y) || !finite(a) || !finite(b) || !finite(x) {
    return y
  }
  let exact = dyadic_sum(
    dyadic_product(dyadic_value(a), dyadic_value(x)),
    dyadic_value(b),
  )
  dyadic_quotient(exact, (@bigint.BigInt::from_int(1), 0))
}
