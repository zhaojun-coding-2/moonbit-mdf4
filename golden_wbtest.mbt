// Golden values are from an external asammdf process, not a copied decoder.

///|
test "asammdf golden compression 0" {
  let m = open(@fixture.core_0()).unwrap()
  assert_eq(m.version(), "4.11")
  let s = m.extract_channel("identity").unwrap()
  assert_eq(s.values.length(), 6)
  guard s.values[0] is Number(v) else { fail("expected number") }
  assert_true((v - 0.0).abs() < 1.0e-10)
  assert_eq(s.valid[0], true)
  assert_eq(s.timestamps[0], 0.0)
  guard s.values[1] is Number(v) else { fail("expected number") }
  assert_true((v - 1.0).abs() < 1.0e-10)
  assert_eq(s.valid[1], true)
  assert_eq(s.timestamps[1], 0.1)
  guard s.values[2] is Number(v) else { fail("expected number") }
  assert_true((v - 2.0).abs() < 1.0e-10)
  assert_eq(s.valid[2], false)
  assert_eq(s.timestamps[2], 0.2)
  guard s.values[3] is Number(v) else { fail("expected number") }
  assert_true((v - 3.0).abs() < 1.0e-10)
  assert_eq(s.valid[3], true)
  assert_eq(s.timestamps[3], 0.3)
  guard s.values[4] is Number(v) else { fail("expected number") }
  assert_true((v - 4.0).abs() < 1.0e-10)
  assert_eq(s.valid[4], true)
  assert_eq(s.timestamps[4], 0.4)
  guard s.values[5] is Number(v) else { fail("expected number") }
  assert_true((v - 5.0).abs() < 1.0e-10)
  assert_eq(s.valid[5], true)
  assert_eq(s.timestamps[5], 0.5)
  let s = m.extract_channel("linear").unwrap()
  assert_eq(s.values.length(), 6)
  guard s.values[0] is Number(v) else { fail("expected number") }
  assert_true((v - -3.0).abs() < 1.0e-10)
  assert_eq(s.valid[0], true)
  assert_eq(s.timestamps[0], 0.0)
  guard s.values[1] is Number(v) else { fail("expected number") }
  assert_true((v - -0.5).abs() < 1.0e-10)
  assert_eq(s.valid[1], true)
  assert_eq(s.timestamps[1], 0.1)
  guard s.values[2] is Number(v) else { fail("expected number") }
  assert_true((v - 2.0).abs() < 1.0e-10)
  assert_eq(s.valid[2], false)
  assert_eq(s.timestamps[2], 0.2)
  guard s.values[3] is Number(v) else { fail("expected number") }
  assert_true((v - 4.5).abs() < 1.0e-10)
  assert_eq(s.valid[3], true)
  assert_eq(s.timestamps[3], 0.3)
  guard s.values[4] is Number(v) else { fail("expected number") }
  assert_true((v - 7.0).abs() < 1.0e-10)
  assert_eq(s.valid[4], true)
  assert_eq(s.timestamps[4], 0.4)
  guard s.values[5] is Number(v) else { fail("expected number") }
  assert_true((v - 9.5).abs() < 1.0e-10)
  assert_eq(s.valid[5], true)
  assert_eq(s.timestamps[5], 0.5)
  let s = m.extract_channel("rational").unwrap()
  assert_eq(s.values.length(), 6)
  guard s.values[0] is Number(v) else { fail("expected number") }
  assert_true((v - 1.5).abs() < 1.0e-10)
  assert_eq(s.valid[0], true)
  assert_eq(s.timestamps[0], 0.0)
  guard s.values[1] is Number(v) else { fail("expected number") }
  assert_true((v - 3.0).abs() < 1.0e-10)
  assert_eq(s.valid[1], true)
  assert_eq(s.timestamps[1], 0.1)
  guard s.values[2] is Number(v) else { fail("expected number") }
  assert_true((v - 5.5).abs() < 1.0e-10)
  assert_eq(s.valid[2], false)
  assert_eq(s.timestamps[2], 0.2)
  guard s.values[3] is Number(v) else { fail("expected number") }
  assert_true((v - 9.0).abs() < 1.0e-10)
  assert_eq(s.valid[3], true)
  assert_eq(s.timestamps[3], 0.3)
  guard s.values[4] is Number(v) else { fail("expected number") }
  assert_true((v - 13.5).abs() < 1.0e-10)
  assert_eq(s.valid[4], true)
  assert_eq(s.timestamps[4], 0.4)
  guard s.values[5] is Number(v) else { fail("expected number") }
  assert_true((v - 19.0).abs() < 1.0e-10)
  assert_eq(s.valid[5], true)
  assert_eq(s.timestamps[5], 0.5)
  let s = m.extract_channel("formula").unwrap()
  assert_eq(s.values.length(), 6)
  guard s.values[0] is Number(v) else { fail("expected number") }
  assert_true((v - 0.0).abs() < 1.0e-10)
  assert_eq(s.valid[0], true)
  assert_eq(s.timestamps[0], 0.0)
  guard s.values[1] is Number(v) else { fail("expected number") }
  assert_true((v - 1.8414709848078965).abs() < 1.0e-10)
  assert_eq(s.valid[1], true)
  assert_eq(s.timestamps[1], 0.1)
  guard s.values[2] is Number(v) else { fail("expected number") }
  assert_true((v - 4.909297426825682).abs() < 1.0e-10)
  assert_eq(s.valid[2], false)
  assert_eq(s.timestamps[2], 0.2)
  guard s.values[3] is Number(v) else { fail("expected number") }
  assert_true((v - 9.141120008059866).abs() < 1.0e-10)
  assert_eq(s.valid[3], true)
  assert_eq(s.timestamps[3], 0.3)
  guard s.values[4] is Number(v) else { fail("expected number") }
  assert_true((v - 15.243197504692072).abs() < 1.0e-10)
  assert_eq(s.valid[4], true)
  assert_eq(s.timestamps[4], 0.4)
  guard s.values[5] is Number(v) else { fail("expected number") }
  assert_true((v - 24.04107572533686).abs() < 1.0e-10)
  assert_eq(s.valid[5], true)
  assert_eq(s.timestamps[5], 0.5)
  let s = m.extract_channel("table").unwrap()
  assert_eq(s.values.length(), 6)
  guard s.values[0] is Number(v) else { fail("expected number") }
  assert_true((v - 10.0).abs() < 1.0e-10)
  assert_eq(s.valid[0], true)
  assert_eq(s.timestamps[0], 0.0)
  guard s.values[1] is Number(v) else { fail("expected number") }
  assert_true((v - 20.0).abs() < 1.0e-10)
  assert_eq(s.valid[1], true)
  assert_eq(s.timestamps[1], 0.1)
  guard s.values[2] is Number(v) else { fail("expected number") }
  assert_true((v - 30.0).abs() < 1.0e-10)
  assert_eq(s.valid[2], false)
  assert_eq(s.timestamps[2], 0.2)
  guard s.values[3] is Number(v) else { fail("expected number") }
  assert_true((v - 40.0).abs() < 1.0e-10)
  assert_eq(s.valid[3], true)
  assert_eq(s.timestamps[3], 0.3)
  guard s.values[4] is Number(v) else { fail("expected number") }
  assert_true((v - 35.0).abs() < 1.0e-10)
  assert_eq(s.valid[4], true)
  assert_eq(s.timestamps[4], 0.4)
  guard s.values[5] is Number(v) else { fail("expected number") }
  assert_true((v - 30.0).abs() < 1.0e-10)
  assert_eq(s.valid[5], true)
  assert_eq(s.timestamps[5], 0.5)
  let s = m.extract_channel("enum").unwrap()
  assert_eq(s.values.length(), 6)
  assert_eq(s.values[0], Label("Idle"))
  assert_eq(s.valid[0], true)
  assert_eq(s.timestamps[0], 0.0)
  assert_eq(s.values[1], Label("Run"))
  assert_eq(s.valid[1], true)
  assert_eq(s.timestamps[1], 0.1)
  assert_eq(s.values[2], Label(""))
  assert_eq(s.valid[2], false)
  assert_eq(s.timestamps[2], 0.2)
  assert_eq(s.values[3], Label(""))
  assert_eq(s.valid[3], true)
  assert_eq(s.timestamps[3], 0.3)
  assert_eq(s.values[4], Label(""))
  assert_eq(s.valid[4], true)
  assert_eq(s.timestamps[4], 0.4)
  assert_eq(s.values[5], Label(""))
  assert_eq(s.valid[5], true)
  assert_eq(s.timestamps[5], 0.5)
  let raw = m.read_raw(m.find_channel("uint64").unwrap()).unwrap()
  assert_eq(raw[2], Unsigned(9007199254740993UL))
  assert_eq(raw[5], Unsigned(18446744073709551615UL))
  let raw = m.read_raw(m.find_channel("signed_be").unwrap()).unwrap()
  assert_eq(raw[0], Signed(-128L))
  assert_eq(raw[5], Signed(127L))
}

///|
test "asammdf golden compression 1" {
  let m = open(@fixture.core_1()).unwrap()
  assert_eq(m.version(), "4.11")
  let s = m.extract_channel("identity").unwrap()
  assert_eq(s.values.length(), 6)
  guard s.values[0] is Number(v) else { fail("expected number") }
  assert_true((v - 0.0).abs() < 1.0e-10)
  assert_eq(s.valid[0], true)
  assert_eq(s.timestamps[0], 0.0)
  guard s.values[1] is Number(v) else { fail("expected number") }
  assert_true((v - 1.0).abs() < 1.0e-10)
  assert_eq(s.valid[1], true)
  assert_eq(s.timestamps[1], 0.1)
  guard s.values[2] is Number(v) else { fail("expected number") }
  assert_true((v - 2.0).abs() < 1.0e-10)
  assert_eq(s.valid[2], false)
  assert_eq(s.timestamps[2], 0.2)
  guard s.values[3] is Number(v) else { fail("expected number") }
  assert_true((v - 3.0).abs() < 1.0e-10)
  assert_eq(s.valid[3], true)
  assert_eq(s.timestamps[3], 0.3)
  guard s.values[4] is Number(v) else { fail("expected number") }
  assert_true((v - 4.0).abs() < 1.0e-10)
  assert_eq(s.valid[4], true)
  assert_eq(s.timestamps[4], 0.4)
  guard s.values[5] is Number(v) else { fail("expected number") }
  assert_true((v - 5.0).abs() < 1.0e-10)
  assert_eq(s.valid[5], true)
  assert_eq(s.timestamps[5], 0.5)
  let s = m.extract_channel("linear").unwrap()
  assert_eq(s.values.length(), 6)
  guard s.values[0] is Number(v) else { fail("expected number") }
  assert_true((v - -3.0).abs() < 1.0e-10)
  assert_eq(s.valid[0], true)
  assert_eq(s.timestamps[0], 0.0)
  guard s.values[1] is Number(v) else { fail("expected number") }
  assert_true((v - -0.5).abs() < 1.0e-10)
  assert_eq(s.valid[1], true)
  assert_eq(s.timestamps[1], 0.1)
  guard s.values[2] is Number(v) else { fail("expected number") }
  assert_true((v - 2.0).abs() < 1.0e-10)
  assert_eq(s.valid[2], false)
  assert_eq(s.timestamps[2], 0.2)
  guard s.values[3] is Number(v) else { fail("expected number") }
  assert_true((v - 4.5).abs() < 1.0e-10)
  assert_eq(s.valid[3], true)
  assert_eq(s.timestamps[3], 0.3)
  guard s.values[4] is Number(v) else { fail("expected number") }
  assert_true((v - 7.0).abs() < 1.0e-10)
  assert_eq(s.valid[4], true)
  assert_eq(s.timestamps[4], 0.4)
  guard s.values[5] is Number(v) else { fail("expected number") }
  assert_true((v - 9.5).abs() < 1.0e-10)
  assert_eq(s.valid[5], true)
  assert_eq(s.timestamps[5], 0.5)
  let s = m.extract_channel("rational").unwrap()
  assert_eq(s.values.length(), 6)
  guard s.values[0] is Number(v) else { fail("expected number") }
  assert_true((v - 1.5).abs() < 1.0e-10)
  assert_eq(s.valid[0], true)
  assert_eq(s.timestamps[0], 0.0)
  guard s.values[1] is Number(v) else { fail("expected number") }
  assert_true((v - 3.0).abs() < 1.0e-10)
  assert_eq(s.valid[1], true)
  assert_eq(s.timestamps[1], 0.1)
  guard s.values[2] is Number(v) else { fail("expected number") }
  assert_true((v - 5.5).abs() < 1.0e-10)
  assert_eq(s.valid[2], false)
  assert_eq(s.timestamps[2], 0.2)
  guard s.values[3] is Number(v) else { fail("expected number") }
  assert_true((v - 9.0).abs() < 1.0e-10)
  assert_eq(s.valid[3], true)
  assert_eq(s.timestamps[3], 0.3)
  guard s.values[4] is Number(v) else { fail("expected number") }
  assert_true((v - 13.5).abs() < 1.0e-10)
  assert_eq(s.valid[4], true)
  assert_eq(s.timestamps[4], 0.4)
  guard s.values[5] is Number(v) else { fail("expected number") }
  assert_true((v - 19.0).abs() < 1.0e-10)
  assert_eq(s.valid[5], true)
  assert_eq(s.timestamps[5], 0.5)
  let s = m.extract_channel("formula").unwrap()
  assert_eq(s.values.length(), 6)
  guard s.values[0] is Number(v) else { fail("expected number") }
  assert_true((v - 0.0).abs() < 1.0e-10)
  assert_eq(s.valid[0], true)
  assert_eq(s.timestamps[0], 0.0)
  guard s.values[1] is Number(v) else { fail("expected number") }
  assert_true((v - 1.8414709848078965).abs() < 1.0e-10)
  assert_eq(s.valid[1], true)
  assert_eq(s.timestamps[1], 0.1)
  guard s.values[2] is Number(v) else { fail("expected number") }
  assert_true((v - 4.909297426825682).abs() < 1.0e-10)
  assert_eq(s.valid[2], false)
  assert_eq(s.timestamps[2], 0.2)
  guard s.values[3] is Number(v) else { fail("expected number") }
  assert_true((v - 9.141120008059866).abs() < 1.0e-10)
  assert_eq(s.valid[3], true)
  assert_eq(s.timestamps[3], 0.3)
  guard s.values[4] is Number(v) else { fail("expected number") }
  assert_true((v - 15.243197504692072).abs() < 1.0e-10)
  assert_eq(s.valid[4], true)
  assert_eq(s.timestamps[4], 0.4)
  guard s.values[5] is Number(v) else { fail("expected number") }
  assert_true((v - 24.04107572533686).abs() < 1.0e-10)
  assert_eq(s.valid[5], true)
  assert_eq(s.timestamps[5], 0.5)
  let s = m.extract_channel("table").unwrap()
  assert_eq(s.values.length(), 6)
  guard s.values[0] is Number(v) else { fail("expected number") }
  assert_true((v - 10.0).abs() < 1.0e-10)
  assert_eq(s.valid[0], true)
  assert_eq(s.timestamps[0], 0.0)
  guard s.values[1] is Number(v) else { fail("expected number") }
  assert_true((v - 20.0).abs() < 1.0e-10)
  assert_eq(s.valid[1], true)
  assert_eq(s.timestamps[1], 0.1)
  guard s.values[2] is Number(v) else { fail("expected number") }
  assert_true((v - 30.0).abs() < 1.0e-10)
  assert_eq(s.valid[2], false)
  assert_eq(s.timestamps[2], 0.2)
  guard s.values[3] is Number(v) else { fail("expected number") }
  assert_true((v - 40.0).abs() < 1.0e-10)
  assert_eq(s.valid[3], true)
  assert_eq(s.timestamps[3], 0.3)
  guard s.values[4] is Number(v) else { fail("expected number") }
  assert_true((v - 35.0).abs() < 1.0e-10)
  assert_eq(s.valid[4], true)
  assert_eq(s.timestamps[4], 0.4)
  guard s.values[5] is Number(v) else { fail("expected number") }
  assert_true((v - 30.0).abs() < 1.0e-10)
  assert_eq(s.valid[5], true)
  assert_eq(s.timestamps[5], 0.5)
  let s = m.extract_channel("enum").unwrap()
  assert_eq(s.values.length(), 6)
  assert_eq(s.values[0], Label("Idle"))
  assert_eq(s.valid[0], true)
  assert_eq(s.timestamps[0], 0.0)
  assert_eq(s.values[1], Label("Run"))
  assert_eq(s.valid[1], true)
  assert_eq(s.timestamps[1], 0.1)
  assert_eq(s.values[2], Label(""))
  assert_eq(s.valid[2], false)
  assert_eq(s.timestamps[2], 0.2)
  assert_eq(s.values[3], Label(""))
  assert_eq(s.valid[3], true)
  assert_eq(s.timestamps[3], 0.3)
  assert_eq(s.values[4], Label(""))
  assert_eq(s.valid[4], true)
  assert_eq(s.timestamps[4], 0.4)
  assert_eq(s.values[5], Label(""))
  assert_eq(s.valid[5], true)
  assert_eq(s.timestamps[5], 0.5)
  let raw = m.read_raw(m.find_channel("uint64").unwrap()).unwrap()
  assert_eq(raw[2], Unsigned(9007199254740993UL))
  assert_eq(raw[5], Unsigned(18446744073709551615UL))
  let raw = m.read_raw(m.find_channel("signed_be").unwrap()).unwrap()
  assert_eq(raw[0], Signed(-128L))
  assert_eq(raw[5], Signed(127L))
}

///|
test "asammdf golden compression 2" {
  let m = open(@fixture.core_2()).unwrap()
  assert_eq(m.version(), "4.11")
  let s = m.extract_channel("identity").unwrap()
  assert_eq(s.values.length(), 6)
  guard s.values[0] is Number(v) else { fail("expected number") }
  assert_true((v - 0.0).abs() < 1.0e-10)
  assert_eq(s.valid[0], true)
  assert_eq(s.timestamps[0], 0.0)
  guard s.values[1] is Number(v) else { fail("expected number") }
  assert_true((v - 1.0).abs() < 1.0e-10)
  assert_eq(s.valid[1], true)
  assert_eq(s.timestamps[1], 0.1)
  guard s.values[2] is Number(v) else { fail("expected number") }
  assert_true((v - 2.0).abs() < 1.0e-10)
  assert_eq(s.valid[2], false)
  assert_eq(s.timestamps[2], 0.2)
  guard s.values[3] is Number(v) else { fail("expected number") }
  assert_true((v - 3.0).abs() < 1.0e-10)
  assert_eq(s.valid[3], true)
  assert_eq(s.timestamps[3], 0.3)
  guard s.values[4] is Number(v) else { fail("expected number") }
  assert_true((v - 4.0).abs() < 1.0e-10)
  assert_eq(s.valid[4], true)
  assert_eq(s.timestamps[4], 0.4)
  guard s.values[5] is Number(v) else { fail("expected number") }
  assert_true((v - 5.0).abs() < 1.0e-10)
  assert_eq(s.valid[5], true)
  assert_eq(s.timestamps[5], 0.5)
  let s = m.extract_channel("linear").unwrap()
  assert_eq(s.values.length(), 6)
  guard s.values[0] is Number(v) else { fail("expected number") }
  assert_true((v - -3.0).abs() < 1.0e-10)
  assert_eq(s.valid[0], true)
  assert_eq(s.timestamps[0], 0.0)
  guard s.values[1] is Number(v) else { fail("expected number") }
  assert_true((v - -0.5).abs() < 1.0e-10)
  assert_eq(s.valid[1], true)
  assert_eq(s.timestamps[1], 0.1)
  guard s.values[2] is Number(v) else { fail("expected number") }
  assert_true((v - 2.0).abs() < 1.0e-10)
  assert_eq(s.valid[2], false)
  assert_eq(s.timestamps[2], 0.2)
  guard s.values[3] is Number(v) else { fail("expected number") }
  assert_true((v - 4.5).abs() < 1.0e-10)
  assert_eq(s.valid[3], true)
  assert_eq(s.timestamps[3], 0.3)
  guard s.values[4] is Number(v) else { fail("expected number") }
  assert_true((v - 7.0).abs() < 1.0e-10)
  assert_eq(s.valid[4], true)
  assert_eq(s.timestamps[4], 0.4)
  guard s.values[5] is Number(v) else { fail("expected number") }
  assert_true((v - 9.5).abs() < 1.0e-10)
  assert_eq(s.valid[5], true)
  assert_eq(s.timestamps[5], 0.5)
  let s = m.extract_channel("rational").unwrap()
  assert_eq(s.values.length(), 6)
  guard s.values[0] is Number(v) else { fail("expected number") }
  assert_true((v - 1.5).abs() < 1.0e-10)
  assert_eq(s.valid[0], true)
  assert_eq(s.timestamps[0], 0.0)
  guard s.values[1] is Number(v) else { fail("expected number") }
  assert_true((v - 3.0).abs() < 1.0e-10)
  assert_eq(s.valid[1], true)
  assert_eq(s.timestamps[1], 0.1)
  guard s.values[2] is Number(v) else { fail("expected number") }
  assert_true((v - 5.5).abs() < 1.0e-10)
  assert_eq(s.valid[2], false)
  assert_eq(s.timestamps[2], 0.2)
  guard s.values[3] is Number(v) else { fail("expected number") }
  assert_true((v - 9.0).abs() < 1.0e-10)
  assert_eq(s.valid[3], true)
  assert_eq(s.timestamps[3], 0.3)
  guard s.values[4] is Number(v) else { fail("expected number") }
  assert_true((v - 13.5).abs() < 1.0e-10)
  assert_eq(s.valid[4], true)
  assert_eq(s.timestamps[4], 0.4)
  guard s.values[5] is Number(v) else { fail("expected number") }
  assert_true((v - 19.0).abs() < 1.0e-10)
  assert_eq(s.valid[5], true)
  assert_eq(s.timestamps[5], 0.5)
  let s = m.extract_channel("formula").unwrap()
  assert_eq(s.values.length(), 6)
  guard s.values[0] is Number(v) else { fail("expected number") }
  assert_true((v - 0.0).abs() < 1.0e-10)
  assert_eq(s.valid[0], true)
  assert_eq(s.timestamps[0], 0.0)
  guard s.values[1] is Number(v) else { fail("expected number") }
  assert_true((v - 1.8414709848078965).abs() < 1.0e-10)
  assert_eq(s.valid[1], true)
  assert_eq(s.timestamps[1], 0.1)
  guard s.values[2] is Number(v) else { fail("expected number") }
  assert_true((v - 4.909297426825682).abs() < 1.0e-10)
  assert_eq(s.valid[2], false)
  assert_eq(s.timestamps[2], 0.2)
  guard s.values[3] is Number(v) else { fail("expected number") }
  assert_true((v - 9.141120008059866).abs() < 1.0e-10)
  assert_eq(s.valid[3], true)
  assert_eq(s.timestamps[3], 0.3)
  guard s.values[4] is Number(v) else { fail("expected number") }
  assert_true((v - 15.243197504692072).abs() < 1.0e-10)
  assert_eq(s.valid[4], true)
  assert_eq(s.timestamps[4], 0.4)
  guard s.values[5] is Number(v) else { fail("expected number") }
  assert_true((v - 24.04107572533686).abs() < 1.0e-10)
  assert_eq(s.valid[5], true)
  assert_eq(s.timestamps[5], 0.5)
  let s = m.extract_channel("table").unwrap()
  assert_eq(s.values.length(), 6)
  guard s.values[0] is Number(v) else { fail("expected number") }
  assert_true((v - 10.0).abs() < 1.0e-10)
  assert_eq(s.valid[0], true)
  assert_eq(s.timestamps[0], 0.0)
  guard s.values[1] is Number(v) else { fail("expected number") }
  assert_true((v - 20.0).abs() < 1.0e-10)
  assert_eq(s.valid[1], true)
  assert_eq(s.timestamps[1], 0.1)
  guard s.values[2] is Number(v) else { fail("expected number") }
  assert_true((v - 30.0).abs() < 1.0e-10)
  assert_eq(s.valid[2], false)
  assert_eq(s.timestamps[2], 0.2)
  guard s.values[3] is Number(v) else { fail("expected number") }
  assert_true((v - 40.0).abs() < 1.0e-10)
  assert_eq(s.valid[3], true)
  assert_eq(s.timestamps[3], 0.3)
  guard s.values[4] is Number(v) else { fail("expected number") }
  assert_true((v - 35.0).abs() < 1.0e-10)
  assert_eq(s.valid[4], true)
  assert_eq(s.timestamps[4], 0.4)
  guard s.values[5] is Number(v) else { fail("expected number") }
  assert_true((v - 30.0).abs() < 1.0e-10)
  assert_eq(s.valid[5], true)
  assert_eq(s.timestamps[5], 0.5)
  let s = m.extract_channel("enum").unwrap()
  assert_eq(s.values.length(), 6)
  assert_eq(s.values[0], Label("Idle"))
  assert_eq(s.valid[0], true)
  assert_eq(s.timestamps[0], 0.0)
  assert_eq(s.values[1], Label("Run"))
  assert_eq(s.valid[1], true)
  assert_eq(s.timestamps[1], 0.1)
  assert_eq(s.values[2], Label(""))
  assert_eq(s.valid[2], false)
  assert_eq(s.timestamps[2], 0.2)
  assert_eq(s.values[3], Label(""))
  assert_eq(s.valid[3], true)
  assert_eq(s.timestamps[3], 0.3)
  assert_eq(s.values[4], Label(""))
  assert_eq(s.valid[4], true)
  assert_eq(s.timestamps[4], 0.4)
  assert_eq(s.values[5], Label(""))
  assert_eq(s.valid[5], true)
  assert_eq(s.timestamps[5], 0.5)
  let raw = m.read_raw(m.find_channel("uint64").unwrap()).unwrap()
  assert_eq(raw[2], Unsigned(9007199254740993UL))
  assert_eq(raw[5], Unsigned(18446744073709551615UL))
  let raw = m.read_raw(m.find_channel("signed_be").unwrap()).unwrap()
  assert_eq(raw[0], Signed(-128L))
  assert_eq(raw[5], Signed(127L))
}
