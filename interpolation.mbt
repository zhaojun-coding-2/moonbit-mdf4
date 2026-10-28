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
