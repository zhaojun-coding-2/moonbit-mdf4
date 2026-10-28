///|
priv struct ColumnShape {
  label : String
  unit : String
  value_header : String
  validity_header : String
  valid_value_kinds : Array[String]
} derive(@json.FromJson, ToJson)

///|
priv struct TableShape {
  schema_version : String
  start_ns : String
  row_count : Int32
  origin_header : String
  time_header : String
  columns : Array[ColumnShape]
} derive(@json.FromJson, ToJson)

///|
priv struct View {
  start_ns : String
  columns : Array[ColumnShape]
  times : Array[String]
  rows : Array[Array[Json]]
} derive(ToJson)

///|
priv struct Case {
  name : String
  csv : String
  schema_json : String
  parsed_header : Array[String]
  parsed_rows : Array[Array[String]]
  view : View
} derive(ToJson)

///|
priv struct Rejection {
  name : String
  error : String
} derive(ToJson)

///|
priv struct Report {
  cases : Array[Case]
  rejections : Array[Rejection]
} derive(ToJson)

///|
// This example accepts the producer's homogeneous-kind columns. A union of
// kinds in a column cannot identify the kind of an individual CSV field.
fn consume(text : String, schema_text : String) -> Result[View, String] {
  let schema : TableShape = @json.from_json(@json.parse(schema_text)) catch {
    _ => return Err("schema JSON")
  }
  if schema.schema_version != "mdf4.analysis.schema/1" {
    return Err("schema version")
  }
  let parsed = parse_csv(text)
  let expected_header = [schema.origin_header, schema.time_header]
  for column in schema.columns {
    if column.valid_value_kinds.length() > 1 {
      return Err("ambiguous column kind")
    }
    if column.valid_value_kinds.length() == 1 &&
      column.valid_value_kinds[0] != "number" &&
      column.valid_value_kinds[0] != "label" &&
      column.valid_value_kinds[0] != "data" {
      return Err("unknown column kind")
    }
    expected_header.push(column.value_header)
    expected_header.push(column.validity_header)
  }
  if parsed.header() != expected_header {
    return Err("header")
  }
  if parsed.data().length() != schema.row_count {
    return Err("row count")
  }
  let times = []
  let rows = []
  for source in parsed.data() {
    if source.length() != expected_header.length() {
      return Err("row width")
    }
    if source[0] != schema.start_ns {
      return Err("origin")
    }
    times.push(source[1])
    let cells = []
    for index, column in schema.columns {
      let value = source[2 + index * 2]
      match source[3 + index * 2] {
        "false" => cells.push(Json::null())
        "true" => {
          if column.valid_value_kinds.length() != 1 {
            return Err("missing column kind")
          }
          cells.push(
            Json::object({
              "kind": Json::string(column.valid_value_kinds[0]),
              "text": Json::string(value),
            }),
          )
        }
        _ => return Err("validity")
      }
    }
    rows.push(cells)
  }
  Ok({ start_ns: schema.start_ns, columns: schema.columns, times, rows, })
}

///|
fn parse_csv(text : String) -> @csv.CSV {
  @csv.CSV::parse_string(text, options={
    delimiter: ',',
    allow_newlines_in_quotes: true,
    quote_char: '"',
    skip_empty_lines: true,
    trim_spaces: false,
  })
}

///|
fn show_case(name : String, table : @analysis.AlignedTable) -> Case {
  let text = table.to_csv()
  let schema_text = table.schema_json()
  let parsed = parse_csv(text)
  {
    name,
    csv: text,
    schema_json: schema_text,
    parsed_header: parsed.header(),
    parsed_rows: parsed.data(),
    view: consume(text, schema_text).unwrap(),
  }
}

///|
fn rejection(name : String, text : String, schema_text : String) -> Rejection {
  {
    name,
    error: match consume(text, schema_text) {
      Err(error) => error
      Ok(_) => "unexpected acceptance"
    },
  }
}

///|
fn main {
  let labels = @analysis.align(
    @mdf.open(@special.labels()).unwrap(),
    [{ channel: 3, label: "state 🚦", policy: @mdf.Previous, }],
    [0.0, 0.25, 0.75, 1.0],
  ).unwrap()
  let mixed = @analysis.align(
    @mdf.open(@fixture.mixed()).unwrap(),
    [
      { channel: 1, label: "number", policy: @mdf.Previous, },
      { channel: 2, label: "state", policy: @mdf.Previous, },
      { channel: 3, label: "bytes", policy: @mdf.Previous, },
    ],
    [0.0, 1.0],
  ).unwrap()
  let nonfinite = @analysis.align(
    @mdf.open(@special.nonfinite()).unwrap(),
    [{ channel: 1, label: "special", policy: @mdf.Previous, }],
    [-0.0, 0.1, 0.2],
  ).unwrap()
  let cases = [
    show_case("labels", labels),
    show_case("mixed", mixed),
    show_case("nonfinite", nonfinite),
    show_case(
      "all invalid",
      @analysis.align(
        @mdf.open(@special.labels()).unwrap(),
        [{ channel: 3, label: "state", policy: @mdf.Previous, }],
        [0.0, 1.0],
      ).unwrap(),
    ),
  ]
  // Show the recipe's refusal to invent a per-cell type from a schema union.
  let schema : TableShape = try! @json.from_json(
    @json.parse(cases[1].schema_json),
  )
  let first = schema.columns[0]
  schema.columns[0] = {
    label: first.label,
    unit: first.unit,
    value_header: first.value_header,
    validity_header: first.validity_header,
    valid_value_kinds: ["number", "label"],
  }
  let text = cases[1].csv
  let schema_text = cases[1].schema_json
  let rejections = [
    rejection(
      "version",
      text,
      schema_text.replace(old="mdf4.analysis.schema/1", new="unknown"),
    ),
    rejection(
      "header",
      text.replace(old="\"time_s\"", new="\"wrong\""),
      schema_text,
    ),
    rejection(
      "row count",
      @csv.CSV::from_array([cases[1].parsed_header]).to_string(),
      schema_text,
    ),
    rejection(
      "validity",
      text.replace(old="\"true\"", new="\"maybe\""),
      schema_text,
    ),
    rejection("column union", text, @json.to_json(schema).stringify()),
  ]
  let report : Report = { cases, rejections, }
  println(@json.to_json(report).stringify())
}
