///|
test "finite extreme resampling must not overflow intermediates" {
  let s : Series = {
    name: "extreme",
    unit: "",
    timestamps: [0.0, 1.0],
    values: [Number(1.0e308), Number(-1.0e308)],
    valid: [true, true],
  }
  let actual = resample(s, [0.5], Linear).unwrap()
  assert_eq(actual.values, [Number(0.0)])
  assert_eq(actual.valid, [true])
}

///|
test "CC interpolation shares finite extreme numeric contract" {
  assert_eq(
    convert(Interpolated([0.0, 1.0], [1.0e308, -1.0e308]), Real(0.5)),
    Ok(Number(0.0)),
  )
  assert_eq(
    convert(Interpolated([-1.0e308, 1.0e308], [0.0, 10.0]), Real(0.0)),
    Ok(Number(5.0)),
  )
}

///|
test "finite time spans must not overflow the interpolation ratio" {
  let s : Series = {
    name: "long time",
    unit: "",
    timestamps: [-1.0e308, 1.0e308],
    values: [Number(0.0), Number(10.0)],
    valid: [true, true],
  }
  assert_eq(resample(s, [0.0], Linear).unwrap().values, [Number(5.0)])
}

///|
test "large finite values, subnormal times, endpoints and masks" {
  let s : Series = {
    name: "finite",
    unit: "",
    timestamps: [0.0, 1.0],
    values: [Number(1.0e308), Number(1.5e308)],
    valid: [true, false],
  }
  let actual = resample(s, [0.0, 0.75, 1.0], Linear).unwrap()
  assert_eq(actual.values, [Number(1.0e308), Number(1.375e308), Number(1.5e308)])
  assert_eq(actual.valid, [true, false, false])
  let narrow : Series = {
    name: "subnormal",
    unit: "",
    timestamps: [0.0, 1.0e-323],
    values: [Number(0.0), Number(10.0)],
    valid: [true, true],
  }
  assert_eq(resample(narrow, [5.0e-324], Linear).unwrap().values, [Number(5.0)])
}
