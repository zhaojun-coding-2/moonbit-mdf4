///|
// Compare the exact difference of finite binary64 endpoints with a finite cap.
// Rounded results away from the cap are decisive by monotonicity. At equality,
// TwoDiff's residual recovers the sign of the otherwise hidden roundoff.
// Reference: Shewchuk's public-domain Two_Diff_Tail (see THIRD_PARTY.md).
fn gap_exceeds(hi : Double, lo : Double, limit : Double) -> Bool {
  let gap = hi - lo
  if gap != limit {
    return gap > limit
  }
  let virtual_lo = hi - gap
  let residual = hi - (gap + virtual_lo) + (virtual_lo - lo)
  residual > 0.0
}

///|
// resample has already validated the source/grid clocks and built equal-sized
// output arrays. This adds a mask only; it never resurrects an invalid sample.
fn limit_gaps(
  times : Array[Double],
  raster : Array[Double],
  policy : @mdf.Interpolation,
  limit : Double,
  valid : Array[Bool],
) -> Unit {
  if times.is_empty() {
    return
  }
  let mut index = 0
  for row, time in raster {
    if time < times[0] || time > times[times.length() - 1] {
      continue
    }
    while index + 1 < times.length() && times[index + 1] <= time {
      index += 1
    }
    if time == times[index] {
      continue
    }
    let upper = if policy == @mdf.Previous { time } else { times[index + 1] }
    if gap_exceeds(upper, times[index], limit) {
      valid[row] = false
    }
  }
}
