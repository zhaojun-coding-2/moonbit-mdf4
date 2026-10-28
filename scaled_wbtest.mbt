///|
test "rational large equal remains representable" {
  guard convert(Rational([1.0, 0.0, 0.0, 1.0, 0.0, 0.0]), Real(1.0e+200))
    is Ok(Number(v)) else {
    fail("expected finite rational value")
  }
  assert_true(!v.is_inf() && !v.is_nan())
  assert_true((v - 1.0).abs() <= 8.881784197001252e-16)
}

///|
test "rational small equal remains representable" {
  guard convert(Rational([1.0, 0.0, 0.0, 1.0, 0.0, 0.0]), Real(1.0e-200))
    is Ok(Number(v)) else {
    fail("expected finite rational value")
  }
  assert_true(!v.is_inf() && !v.is_nan())
  assert_true((v - 1.0).abs() <= 8.881784197001252e-16)
}

///|
test "rational subnormal result remains representable" {
  guard convert(Rational([0.0, 0.0, 1.0, 1.0, 0.0, 0.0]), Real(1.0e+155))
    is Ok(Number(v)) else {
    fail("expected finite rational value")
  }
  assert_true(!v.is_inf() && !v.is_nan())
  assert_true((v - 1.0e-310).abs() <= 2.0e-323)
}

///|
test "linear offset restores finite value after an overflowing product" {
  assert_eq(
    convert(LinearScale(1.0e308, -1.0e308), Real(2.0)),
    Ok(Number(1.0e308)),
  )
}

///|
test "rational near a true pole must distinguish a tiny denominator from zero" {
  assert_eq(
    convert(Rational([0.0, 0.0, 1.0, 1.0, -2.0, 1.0]), Real(1.0000000000000002)),
    Ok(Number(2.028240960365167e31)),
  )
}

///|
test "independent exact rational boundary matrix" {
  // equal quadratic e=-1074
  guard convert(Rational([1.0, 0.0, 0.0, 1.0, 0.0, 0.0]), Real(5.0e-324))
    is Ok(Number(v)) else {
    fail("equal quadratic e=-1074")
  }
  assert_eq(v.reinterpret_as_uint64(), 0x3ff0000000000000UL)
  // equal quadratic e=-1022
  guard convert(
      Rational([1.0, 0.0, 0.0, 1.0, 0.0, 0.0]),
      Real(2.2250738585072014e-308),
    )
    is Ok(Number(v)) else {
    fail("equal quadratic e=-1022")
  }
  assert_eq(v.reinterpret_as_uint64(), 0x3ff0000000000000UL)
  // equal quadratic e=-700
  guard convert(
      Rational([1.0, 0.0, 0.0, 1.0, 0.0, 0.0]),
      Real(1.90109156629516e-211),
    )
    is Ok(Number(v)) else {
    fail("equal quadratic e=-700")
  }
  assert_eq(v.reinterpret_as_uint64(), 0x3ff0000000000000UL)
  // equal quadratic e=-540
  guard convert(
      Rational([1.0, 0.0, 0.0, 1.0, 0.0, 0.0]),
      Real(2.778448436856347e-163),
    )
    is Ok(Number(v)) else {
    fail("equal quadratic e=-540")
  }
  assert_eq(v.reinterpret_as_uint64(), 0x3ff0000000000000UL)
  // equal quadratic e=-537
  guard convert(
      Rational([1.0, 0.0, 0.0, 1.0, 0.0, 0.0]),
      Real(2.2227587494850775e-162),
    )
    is Ok(Number(v)) else {
    fail("equal quadratic e=-537")
  }
  assert_eq(v.reinterpret_as_uint64(), 0x3ff0000000000000UL)
  // equal quadratic e=-512
  guard convert(
      Rational([1.0, 0.0, 0.0, 1.0, 0.0, 0.0]),
      Real(7.458340731200207e-155),
    )
    is Ok(Number(v)) else {
    fail("equal quadratic e=-512")
  }
  assert_eq(v.reinterpret_as_uint64(), 0x3ff0000000000000UL)
  // equal quadratic e=-256
  guard convert(
      Rational([1.0, 0.0, 0.0, 1.0, 0.0, 0.0]),
      Real(8.636168555094445e-78),
    )
    is Ok(Number(v)) else {
    fail("equal quadratic e=-256")
  }
  assert_eq(v.reinterpret_as_uint64(), 0x3ff0000000000000UL)
  // equal quadratic e=-1
  guard convert(Rational([1.0, 0.0, 0.0, 1.0, 0.0, 0.0]), Real(0.5))
    is Ok(Number(v)) else {
    fail("equal quadratic e=-1")
  }
  assert_eq(v.reinterpret_as_uint64(), 0x3ff0000000000000UL)
  // equal quadratic e=0
  guard convert(Rational([1.0, 0.0, 0.0, 1.0, 0.0, 0.0]), Real(1.0))
    is Ok(Number(v)) else {
    fail("equal quadratic e=0")
  }
  assert_eq(v.reinterpret_as_uint64(), 0x3ff0000000000000UL)
  // equal quadratic e=1
  guard convert(Rational([1.0, 0.0, 0.0, 1.0, 0.0, 0.0]), Real(2.0))
    is Ok(Number(v)) else {
    fail("equal quadratic e=1")
  }
  assert_eq(v.reinterpret_as_uint64(), 0x3ff0000000000000UL)
  // equal quadratic e=256
  guard convert(
      Rational([1.0, 0.0, 0.0, 1.0, 0.0, 0.0]),
      Real(1.157920892373162e+77),
    )
    is Ok(Number(v)) else {
    fail("equal quadratic e=256")
  }
  assert_eq(v.reinterpret_as_uint64(), 0x3ff0000000000000UL)
  // equal quadratic e=512
  guard convert(
      Rational([1.0, 0.0, 0.0, 1.0, 0.0, 0.0]),
      Real(1.3407807929942597e+154),
    )
    is Ok(Number(v)) else {
    fail("equal quadratic e=512")
  }
  assert_eq(v.reinterpret_as_uint64(), 0x3ff0000000000000UL)
  // equal quadratic e=537
  guard convert(
      Rational([1.0, 0.0, 0.0, 1.0, 0.0, 0.0]),
      Real(4.4989137945431964e+161),
    )
    is Ok(Number(v)) else {
    fail("equal quadratic e=537")
  }
  assert_eq(v.reinterpret_as_uint64(), 0x3ff0000000000000UL)
  // equal quadratic e=540
  guard convert(
      Rational([1.0, 0.0, 0.0, 1.0, 0.0, 0.0]),
      Real(3.599131035634557e+162),
    )
    is Ok(Number(v)) else {
    fail("equal quadratic e=540")
  }
  assert_eq(v.reinterpret_as_uint64(), 0x3ff0000000000000UL)
  // equal quadratic e=700
  guard convert(
      Rational([1.0, 0.0, 0.0, 1.0, 0.0, 0.0]),
      Real(5.260135901548374e+210),
    )
    is Ok(Number(v)) else {
    fail("equal quadratic e=700")
  }
  assert_eq(v.reinterpret_as_uint64(), 0x3ff0000000000000UL)
  // equal quadratic e=1023
  guard convert(
      Rational([1.0, 0.0, 0.0, 1.0, 0.0, 0.0]),
      Real(8.98846567431158e+307),
    )
    is Ok(Number(v)) else {
    fail("equal quadratic e=1023")
  }
  assert_eq(v.reinterpret_as_uint64(), 0x3ff0000000000000UL)
  // reciprocal quadratic e=-512
  assert_true(
    convert(
      Rational([0.0, 0.0, 1.0, 1.0, 0.0, 0.0]),
      Real(7.458340731200207e-155),
    )
    is Err(InvalidFormula(_)),
  )
  // reciprocal quadratic e=-511
  guard convert(
      Rational([0.0, 0.0, 1.0, 1.0, 0.0, 0.0]),
      Real(1.4916681462400413e-154),
    )
    is Ok(Number(v)) else {
    fail("reciprocal quadratic e=-511")
  }
  assert_eq(v.reinterpret_as_uint64(), 0x7fd0000000000000UL)
  // reciprocal quadratic e=511
  guard convert(
      Rational([0.0, 0.0, 1.0, 1.0, 0.0, 0.0]),
      Real(6.703903964971299e+153),
    )
    is Ok(Number(v)) else {
    fail("reciprocal quadratic e=511")
  }
  assert_eq(v.reinterpret_as_uint64(), 0x0010000000000000UL)
  // reciprocal quadratic e=512
  guard convert(
      Rational([0.0, 0.0, 1.0, 1.0, 0.0, 0.0]),
      Real(1.3407807929942597e+154),
    )
    is Ok(Number(v)) else {
    fail("reciprocal quadratic e=512")
  }
  assert_eq(v.reinterpret_as_uint64(), 0x0004000000000000UL)
  // reciprocal quadratic e=537
  guard convert(
      Rational([0.0, 0.0, 1.0, 1.0, 0.0, 0.0]),
      Real(4.4989137945431964e+161),
    )
    is Ok(Number(v)) else {
    fail("reciprocal quadratic e=537")
  }
  assert_eq(v.reinterpret_as_uint64(), 0x0000000000000001UL)
  // reciprocal quadratic e=538
  guard convert(
      Rational([0.0, 0.0, 1.0, 1.0, 0.0, 0.0]),
      Real(8.997827589086393e+161),
    )
    is Ok(Number(v)) else {
    fail("reciprocal quadratic e=538")
  }
  assert_eq(v.reinterpret_as_uint64(), 0x0000000000000000UL)
  // pole boundary
  assert_true(
    convert(Rational([0.0, 0.0, 1.0, 1.0, -2.0, 1.0]), Real(1.0))
    is Err(InvalidFormula(_)),
  )
  // pole boundary
  guard convert(
      Rational([0.0, 0.0, 1.0, 1.0, -2.0, 1.0]),
      Real(1.0000000000000002),
    )
    is Ok(Number(v)) else {
    fail("pole boundary")
  }
  assert_eq(v.reinterpret_as_uint64(), 0x4670000000000000UL)
  // pole boundary
  guard convert(
      Rational([0.0, 0.0, 1.0, 1.0, -2.0, 1.0]),
      Real(0.9999999999999999),
    )
    is Ok(Number(v)) else {
    fail("pole boundary")
  }
  assert_eq(v.reinterpret_as_uint64(), 0x4690000000000000UL)
  // overflow cancellation
  guard convert(
      Rational([1.0e+308, 1.0e+308, -1.0e+308, 0.0, 0.0, 1.0]),
      Real(1.0),
    )
    is Ok(Number(v)) else {
    fail("overflow cancellation")
  }
  assert_eq(v.reinterpret_as_uint64(), 0x7fe1ccf385ebc8a0UL)
  // tiny cancellation residual
  guard convert(
      Rational([1.0e+308, -1.0e+308, 1.0e-308, 0.0, 0.0, 1.0]),
      Real(1.0),
    )
    is Ok(Number(v)) else {
    fail("tiny cancellation residual")
  }
  assert_eq(v.reinterpret_as_uint64(), 0x000730d67819e8d2UL)
  // negative tiny denominator
  guard convert(Rational([1.0, 0.0, 0.0, -1.0, 0.0, 0.0]), Real(1.0e-200))
    is Ok(Number(v)) else {
    fail("negative tiny denominator")
  }
  assert_eq(v.reinterpret_as_uint64(), 0xbff0000000000000UL)
  // underflow amplified quotient
  guard convert(Rational([1.0, 0.0, 0.0, 0.0, 0.0, 1.0e-308]), Real(1.0e-200))
    is Ok(Number(v)) else {
    fail("underflow amplified quotient")
  }
  assert_eq(v.reinterpret_as_uint64(), 0x2cd4dbf7b3f71cb7UL)
  // small coefficient large x
  guard convert(Rational([5.0e-324, 0.0, 0.0, 0.0, 0.0, 1.0]), Real(1.0e+308))
    is Ok(Number(v)) else {
    fail("small coefficient large x")
  }
  assert_eq(v.reinterpret_as_uint64(), 0x7cb3cdc6cce67f0bUL)
  // normal midpoint ties even
  guard convert(
      Rational([0.0, 2.0, 1.0, 0.0, 0.0, 9007199254740992.0]),
      Real(4503599627370496.0),
    )
    is Ok(Number(v)) else {
    fail("normal midpoint ties even")
  }
  assert_eq(v.reinterpret_as_uint64(), 0x3ff0000000000000UL)
  // normal midpoint ties even
  guard convert(
      Rational([0.0, 2.0, 3.0, 0.0, 0.0, 9007199254740992.0]),
      Real(4503599627370496.0),
    )
    is Ok(Number(v)) else {
    fail("normal midpoint ties even")
  }
  assert_eq(v.reinterpret_as_uint64(), 0x3ff0000000000002UL)
  // subnormal midpoint ties even
  guard convert(Rational([0.0, 0.0, 5.0e-324, 0.0, 0.0, 2.0]), Real(0.0))
    is Ok(Number(v)) else {
    fail("subnormal midpoint ties even")
  }
  assert_eq(v.reinterpret_as_uint64(), 0x0000000000000000UL)
  // subnormal midpoint ties even
  guard convert(Rational([0.0, 0.0, 1.5e-323, 0.0, 0.0, 2.0]), Real(0.0))
    is Ok(Number(v)) else {
    fail("subnormal midpoint ties even")
  }
  assert_eq(v.reinterpret_as_uint64(), 0x0000000000000002UL)
  // subnormal midpoint ties even
  guard convert(Rational([0.0, 0.0, -5.0e-324, 0.0, 0.0, 2.0]), Real(0.0))
    is Ok(Number(v)) else {
    fail("subnormal midpoint ties even")
  }
  assert_eq(v.reinterpret_as_uint64(), 0x8000000000000000UL)
  // maximum finite rounding
  guard convert(
      Rational([
        0.0, 1.7976931348623157e+308, 4.9896007738368e+291, 0.0, 0.0, 1.0,
      ]),
      Real(1.0),
    )
    is Ok(Number(v)) else {
    fail("maximum finite rounding")
  }
  assert_eq(v.reinterpret_as_uint64(), 0x7fefffffffffffffUL)
  // maximum finite rounding
  assert_true(
    convert(
      Rational([
        0.0, 1.7976931348623157e+308, 9.9792015476736e+291, 0.0, 0.0, 1.0,
      ]),
      Real(1.0),
    )
    is Err(InvalidFormula(_)),
  )
  // identical true zero
  assert_true(
    convert(Rational([1.0, 0.0, 0.0, 1.0, 0.0, 0.0]), Real(0.0))
    is Err(InvalidFormula(_)),
  )
}

///|
test "scaled conversions preserve non-finite and true overflow errors" {
  for x in [0.0 / 0.0, 1.0 / 0.0, -1.0 / 0.0] {
    assert_true(
      convert(Rational([1.0, 0.0, 0.0, 1.0, 0.0, 0.0]), Real(x))
      is Err(InvalidFormula(_)),
    )
  }
  assert_true(
    convert(Rational([1.0 / 0.0, 0.0, 1.0, 0.0, 0.0, 1.0]), Real(1.0))
    is Err(InvalidFormula(_)),
  )
  assert_true(
    convert(LinearScale(1.0e308, 1.0e308), Real(2.0)) is Err(InvalidFormula(_)),
  )
}
