///|
priv struct Input {
  name : String
  lo : Double
  hi : Double
  a : Double
  b : Double
  queries : Array[Double]
  valid : Array[Bool]
}

///|
priv struct Output {
  name : String
  cc4 : Array[String]
  linear : Array[String]
  linear_valid : Array[Bool]
  previous : Array[String]
  previous_valid : Array[Bool]
} derive(ToJson)

///|
fn number_bits(value : @mdf.Value) -> String {
  match value {
    @mdf.Number(n) => {
      if n.is_nan() {
        return "NaN"
      }
      if n.is_inf() {
        return if n < 0.0 { "-Infinity" } else { "+Infinity" }
      }
      let mut hex = n.reinterpret_as_uint64().to_string(radix=16)
      while hex.length() < 16 {
        hex = "0" + hex
      }
      hex
    }
    _ => "unexpected non-number"
  }
}

///|
fn main {
  // Inputs are frozen binary64 bit patterns, independent of the implementation.
  let inputs : Array[Input] = [
    {
      name: "left-underflow",
      lo: 0x0000000000000000UL.reinterpret_as_double(),
      hi: 0x7e70000000000000UL.reinterpret_as_double(),
      a: 0x0000000000000000UL.reinterpret_as_double(),
      b: 0x7e70000000000000UL.reinterpret_as_double(),
      queries: [
        0x0000000000000000UL.reinterpret_as_double(),
        0x39b0000000000000UL.reinterpret_as_double(),
        0x7e70000000000000UL.reinterpret_as_double(),
      ],
      valid: [true, true],
    },
    {
      name: "right-rounded-one",
      lo: 0xfe70000000000000UL.reinterpret_as_double(),
      hi: 0x0000000000000000UL.reinterpret_as_double(),
      a: 0xfe70000000000000UL.reinterpret_as_double(),
      b: 0x0000000000000000UL.reinterpret_as_double(),
      queries: [
        0xfe70000000000000UL.reinterpret_as_double(),
        0xbff0000000000000UL.reinterpret_as_double(),
        0x0000000000000000UL.reinterpret_as_double(),
      ],
      valid: [true, true],
    },
    {
      name: "left-subnormal-quantization",
      lo: 0x0000000000000000UL.reinterpret_as_double(),
      hi: 0x7e70000000000000UL.reinterpret_as_double(),
      a: 0x0000000000000000UL.reinterpret_as_double(),
      b: 0x7e70000000000000UL.reinterpret_as_double(),
      queries: [
        0x0000000000000000UL.reinterpret_as_double(),
        0x3b58000000000000UL.reinterpret_as_double(),
        0x7e70000000000000UL.reinterpret_as_double(),
      ],
      valid: [true, false],
    },
    {
      name: "right-near-end",
      lo: 0xfe70000000000000UL.reinterpret_as_double(),
      hi: 0x0000000000000000UL.reinterpret_as_double(),
      a: 0xfe70000000000000UL.reinterpret_as_double(),
      b: 0x0000000000000000UL.reinterpret_as_double(),
      queries: [
        0xfe70000000000000UL.reinterpret_as_double(),
        0xfb28000000000000UL.reinterpret_as_double(),
        0x0000000000000000UL.reinterpret_as_double(),
      ],
      valid: [false, true],
    },
    {
      name: "negative-slope",
      lo: 0x0000000000000000UL.reinterpret_as_double(),
      hi: 0x7e70000000000000UL.reinterpret_as_double(),
      a: 0x0000000000000000UL.reinterpret_as_double(),
      b: 0xfe70000000000000UL.reinterpret_as_double(),
      queries: [
        0x0000000000000000UL.reinterpret_as_double(),
        0x39b0000000000000UL.reinterpret_as_double(),
        0x7e70000000000000UL.reinterpret_as_double(),
      ],
      valid: [true, true],
    },
    {
      name: "cancellation",
      lo: 0x0000000000000000UL.reinterpret_as_double(),
      hi: 0x7e70000000000000UL.reinterpret_as_double(),
      a: 0xb9b0000000000000UL.reinterpret_as_double(),
      b: 0x7e70000000000000UL.reinterpret_as_double(),
      queries: [
        0x0000000000000000UL.reinterpret_as_double(),
        0x39b0000000000000UL.reinterpret_as_double(),
        0x7e70000000000000UL.reinterpret_as_double(),
      ],
      valid: [true, true],
    },
    {
      name: "minimum-output",
      lo: 0x0000000000000000UL.reinterpret_as_double(),
      hi: 0x7e70000000000000UL.reinterpret_as_double(),
      a: 0x0000000000000000UL.reinterpret_as_double(),
      b: 0x7e70000000000000UL.reinterpret_as_double(),
      queries: [
        0x0000000000000000UL.reinterpret_as_double(),
        0x0000000000000001UL.reinterpret_as_double(),
        0x7e70000000000000UL.reinterpret_as_double(),
      ],
      valid: [true, true],
    },
    {
      name: "true-underflow",
      lo: 0x0000000000000000UL.reinterpret_as_double(),
      hi: 0x7e70000000000000UL.reinterpret_as_double(),
      a: 0x0000000000000000UL.reinterpret_as_double(),
      b: 0x39b0000000000000UL.reinterpret_as_double(),
      queries: [
        0x0000000000000000UL.reinterpret_as_double(),
        0x39b0000000000000UL.reinterpret_as_double(),
        0x7e70000000000000UL.reinterpret_as_double(),
      ],
      valid: [true, true],
    },
    {
      name: "wide-span",
      lo: 0xfe70000000000000UL.reinterpret_as_double(),
      hi: 0x7e70000000000000UL.reinterpret_as_double(),
      a: 0x0000000000000000UL.reinterpret_as_double(),
      b: 0x4024000000000000UL.reinterpret_as_double(),
      queries: [
        0xfe70000000000000UL.reinterpret_as_double(),
        0x0000000000000000UL.reinterpret_as_double(),
        0x7e70000000000000UL.reinterpret_as_double(),
      ],
      valid: [true, true],
    },
    {
      name: "subnormal-clock",
      lo: 0x0000000000000000UL.reinterpret_as_double(),
      hi: 0x0000000000000002UL.reinterpret_as_double(),
      a: 0x0000000000000000UL.reinterpret_as_double(),
      b: 0x4024000000000000UL.reinterpret_as_double(),
      queries: [
        0x0000000000000000UL.reinterpret_as_double(),
        0x0000000000000001UL.reinterpret_as_double(),
        0x0000000000000002UL.reinterpret_as_double(),
      ],
      valid: [true, true],
    },
    {
      name: "ordinary-and-outside",
      lo: 0x0000000000000000UL.reinterpret_as_double(),
      hi: 0x4010000000000000UL.reinterpret_as_double(),
      a: 0x3ff0000000000000UL.reinterpret_as_double(),
      b: 0x4022000000000000UL.reinterpret_as_double(),
      queries: [
        0xbff0000000000000UL.reinterpret_as_double(),
        0x0000000000000000UL.reinterpret_as_double(),
        0x3ff0000000000000UL.reinterpret_as_double(),
        0x4000000000000000UL.reinterpret_as_double(),
        0x4008000000000000UL.reinterpret_as_double(),
        0x4010000000000000UL.reinterpret_as_double(),
        0x4014000000000000UL.reinterpret_as_double(),
      ],
      valid: [true, false],
    },
    {
      name: "signed-zero",
      lo: 0x0000000000000000UL.reinterpret_as_double(),
      hi: 0x7e70000000000000UL.reinterpret_as_double(),
      a: 0x8000000000000000UL.reinterpret_as_double(),
      b: 0x0000000000000000UL.reinterpret_as_double(),
      queries: [
        0x0000000000000000UL.reinterpret_as_double(),
        0x39b0000000000000UL.reinterpret_as_double(),
        0x7e70000000000000UL.reinterpret_as_double(),
      ],
      valid: [true, true],
    },
    {
      name: "nonfinite-unused-right",
      lo: 0x0000000000000000UL.reinterpret_as_double(),
      hi: 0x7e70000000000000UL.reinterpret_as_double(),
      a: 0x3ff0000000000000UL.reinterpret_as_double(),
      b: 1.0 / 0.0,
      queries: [
        0x0000000000000000UL.reinterpret_as_double(),
        0x39b0000000000000UL.reinterpret_as_double(),
        0x7e70000000000000UL.reinterpret_as_double(),
      ],
      valid: [true, true],
    },
    {
      name: "nonfinite-unused-left",
      lo: 0xfe70000000000000UL.reinterpret_as_double(),
      hi: 0x0000000000000000UL.reinterpret_as_double(),
      a: 1.0 / 0.0,
      b: 0x3ff0000000000000UL.reinterpret_as_double(),
      queries: [
        0xfe70000000000000UL.reinterpret_as_double(),
        0xbff0000000000000UL.reinterpret_as_double(),
        0x0000000000000000UL.reinterpret_as_double(),
      ],
      valid: [true, true],
    },
  ]
  let outputs : Array[Output] = []
  for input in inputs {
    let source : @mdf.Series = {
      name: input.name,
      unit: "u",
      timestamps: [input.lo, input.hi],
      values: [@mdf.Number(input.a), @mdf.Number(input.b)],
      valid: input.valid,
    }
    let linear = @mdf.resample(source, input.queries, @mdf.Linear).unwrap()
    let previous = @mdf.resample(source, input.queries, @mdf.Previous).unwrap()
    let cc4 : Array[String] = []
    for x in input.queries {
      match
        @mdf.convert(
          @mdf.Interpolated([input.lo, input.hi], [input.a, input.b]),
          @mdf.Real(x),
        ) {
        Ok(value) => cc4.push(number_bits(value))
        Err(error) => cc4.push("error:" + error.to_repr().to_string())
      }
    }
    outputs.push({
      name: input.name,
      cc4,
      linear: linear.values.map(number_bits),
      linear_valid: linear.valid,
      previous: previous.values.map(number_bits),
      previous_valid: previous.valid,
    })
  }
  println(@json.to_json(outputs).stringify())
}
