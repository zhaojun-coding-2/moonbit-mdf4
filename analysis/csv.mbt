///|
// Default numeric printing normalizes negative zero on some backends.
// Preserve its sign for numeric CSV consumers, including requested time axes.
fn csv_number(number : Double) -> String {
  if number.reinterpret_as_uint64() == 0x8000000000000000UL {
    "-0"
  } else {
    number.to_string()
  }
}

///|
fn write_csv_field(out : StringBuilder, text : String) -> Unit {
  out.write_char('"')
  for c in text.to_array() {
    if c == '"' {
      out.write_char('"')
    }
    out.write_char(c)
  }
  out.write_char('"')
}

///|
fn csv_value(value : @mdf.Value) -> String {
  match value {
    @mdf.Number(number) => csv_number(number)
    @mdf.Label(text) => text
    @mdf.Data(bytes) => {
      let out = StringBuilder()
      let digits = [
        '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e',
        'f',
      ]
      out.write_string("0x")
      for byte in bytes {
        out.write_char(digits[byte.to_int() >> 4])
        out.write_char(digits[byte.to_int() & 15])
      }
      out.to_string()
    }
  }
}

///|
/// CSV data interchange with CRLF records and paired validity columns.
/// Invalid/outside-domain values are blank; valid empty labels retain true.
/// Valid NaN/Infinity keep their text; bytes are lowercase 0x-prefixed hex.
pub fn AlignedTable::to_csv(self : AlignedTable) -> String {
  let out = StringBuilder()
  write_csv_field(out, "start_ns")
  out.write_char(',')
  write_csv_field(out, "time_s")
  for column in self.data {
    let header = value_header(column.label, column.unit)
    out.write_char(',')
    write_csv_field(out, header)
    out.write_char(',')
    write_csv_field(out, "\{header}__valid")
  }
  out.write_string("\r\n")
  for i, time in self.grid {
    write_csv_field(out, self.origin.to_string())
    out.write_char(',')
    write_csv_field(out, csv_number(time))
    for column in self.data {
      out.write_char(',')
      write_csv_field(
        out,
        if column.valid[i] {
          csv_value(column.values[i])
        } else {
          ""
        },
      )
      out.write_char(',')
      write_csv_field(out, if column.valid[i] { "true" } else { "false" })
    }
    out.write_string("\r\n")
  }
  out.to_string()
}
