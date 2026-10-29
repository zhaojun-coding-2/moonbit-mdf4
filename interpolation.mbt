///|
// For finite lo <= x <= hi, lo < hi. Scaling is needed only when
// subtracting the endpoints overflows; keeping narrow spans unscaled also
// preserves intervals made of subnormal values.
fn interpolation_fraction(lo : Double, hi : Double, x : Double) -> Double {
  if x == lo {
    return 0.0
  }
  if x == hi {
    return 1.0
  }
  let width = hi - lo
  if width.is_inf() {
    (x * 0.5 - lo * 0.5) / (hi * 0.5 - lo * 0.5)
  } else {
    (x - lo) / width
  }
}

///|
// Preserve the convex-combination contract without forming b-a for
// opposite-sign endpoints. Same-sign subtraction is finite and avoids the
// premature product overflow of (b-a)*(x-lo)/(hi-lo).
fn interpolate_finite(a : Double, b : Double, u : Double) -> Double {
  if u == 0.0 {
    return a
  }
  if u == 1.0 {
    return b
  }
  if (a <= 0.0 && b >= 0.0) || (a >= 0.0 && b <= 0.0) {
    (1.0 - u) * a + u * b
  } else {
    a + u * (b - a)
  }
}

///|
// Avoid losing a small, representable displacement by first rounding a
// dimensionless fraction near 0 or 1. Work from the nearer bracket endpoint;
// when that fraction is subnormal, reuse the exact dyadic arithmetic already
// used by numeric conversions. Ordinary fractions retain the floating path.
fn interpolate_point(
  a : Double,
  b : Double,
  lo : Double,
  hi : Double,
  x : Double,
) -> Double raise MdfError {
  if x == lo {
    return a
  }
  if x == hi {
    return b
  }
  // Preserve existing selected/unused nonfinite and signed-zero behavior.
  if !finite(a) || !finite(b) || a == b {
    return interpolate_finite(a, b, interpolation_fraction(lo, hi, x))
  }
  let from_right = hi - x < x - lo
  let fraction = if from_right {
    interpolation_fraction(-hi, -lo, -x)
  } else {
    interpolation_fraction(lo, hi, x)
  }
  if fraction >= 0x1.0p-1022 {
    return if from_right {
      interpolate_finite(b, a, fraction)
    } else {
      interpolate_finite(a, b, fraction)
    }
  }
  // (a*(hi-x) + b*(x-lo)) / (hi-lo), without rounding the weights first.
  // The caller has already checked finite, strictly increasing brackets.
  let left = dyadic_sum(dyadic_value(hi), dyadic_value(-x))
  let right = dyadic_sum(dyadic_value(x), dyadic_value(-lo))
  let span = dyadic_sum(dyadic_value(hi), dyadic_value(-lo))
  dyadic_quotient(
    dyadic_sum(
      dyadic_product(dyadic_value(a), left),
      dyadic_product(dyadic_value(b), right),
    ),
    span,
  )
}
