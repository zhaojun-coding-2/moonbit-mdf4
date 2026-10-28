///|
priv struct ColumnSchema {
  channel : Int32
  label : String
  source_name : String
  unit : String
  interpolation : String
  value_header : String
  validity_header : String
  valid_rows : Int32
  invalid_rows : Int32
  valid_value_kinds : Array[String]
} derive(ToJson)

///|
priv struct TableSchema {
  schema_version : String
  start_ns : String
  row_count : Int32
  origin_header : String
  time_header : String
  max_gap_seconds : Json
  first_time : Json
  last_time : Json
  columns : Array[ColumnSchema]
} derive(ToJson)

///|
/// A versioned description of this aligned result, including settings and
/// observed kinds of valid emitted values. Empty/all-invalid columns have no
/// observed kind. This metadata is not a reversible MDF or CSVW encoding.
pub fn AlignedTable::schema_json(self : AlignedTable) -> String {
  let columns : Array[ColumnSchema] = []
  for column in self.data {
    let mut valid_rows = 0
    let mut number = false
    let mut label = false
    let mut data = false
    for row, value in column.values {
      if !column.valid[row] {
        continue
      }
      valid_rows += 1
      match value {
        @mdf.Number(_) => number = true
        @mdf.Label(_) => label = true
        @mdf.Data(_) => data = true
      }
    }
    let kinds : Array[String] = []
    if number {
      kinds.push("number")
    }
    if label {
      kinds.push("label")
    }
    if data {
      kinds.push("data")
    }
    let header = value_header(column.label, column.unit)
    columns.push({
      channel: column.channel,
      label: column.label,
      source_name: column.name,
      unit: column.unit,
      interpolation: if column.policy == @mdf.Previous {
        "previous"
      } else {
        "linear"
      },
      value_header: header,
      validity_header: "\{header}__valid",
      valid_rows,
      invalid_rows: self.grid.length() - valid_rows,
      valid_value_kinds: kinds,
    })
  }
  let schema : TableSchema = {
    schema_version: "mdf4.analysis.schema/1",
    start_ns: self.origin.to_string(),
    row_count: self.grid.length(),
    origin_header: "start_ns",
    time_header: "time_s",
    max_gap_seconds: match self.gap {
      Some(limit) => Json::string(csv_number(limit))
      None => Json::null()
    },
    first_time: if self.grid.is_empty() {
      Json::null()
    } else {
      Json::string(csv_number(self.grid[0]))
    },
    last_time: if self.grid.is_empty() {
      Json::null()
    } else {
      Json::string(csv_number(self.grid[self.grid.length() - 1]))
    },
    columns,
  }
  @json.to_json(schema).stringify()
}
