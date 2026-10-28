///|
pub(all) suberror AnalysisError {
  InvalidRequest(String)
  CellLimit
  Channel(String, Int32, @mdf.MdfError)
} derive(Debug, Eq)

///|
/// Select by channel index to disambiguate duplicate source names.
pub(all) struct ChannelRequest {
  channel : Int32
  label : String
  policy : @mdf.Interpolation
} derive(Debug)

///|
/// A detached snapshot. Invalid samples retain their value and validity bit.
pub(all) struct AlignedColumn {
  channel : Int32
  label : String
  name : String
  unit : String
  policy : @mdf.Interpolation
  values : Array[@mdf.Value]
  valid : Array[Bool]
} derive(Debug)

///|
/// Constructed only by align, preserving equal grid/value/mask lengths.
pub struct AlignedTable {
  origin : UInt64
  grid : Array[Double]
  data : Array[AlignedColumn]
  gap : Double?
}

///|
pub fn AlignedTable::start_ns(self : AlignedTable) -> UInt64 {
  self.origin
}

///|
pub fn AlignedTable::row_count(self : AlignedTable) -> Int32 {
  self.grid.length()
}

///|
pub fn AlignedTable::column_count(self : AlignedTable) -> Int32 {
  self.data.length()
}

///|
pub fn AlignedTable::timestamps(self : AlignedTable) -> Array[Double] {
  self.grid.copy()
}

///|
pub fn AlignedTable::columns(self : AlignedTable) -> Array[AlignedColumn] {
  self.data.map(c => { ..c, values: c.values.copy(), valid: c.valid.copy(), })
}

///|
fn value_header(label : String, unit : String) -> String {
  if unit == "" {
    label
  } else {
    "\{label} [\{unit}]"
  }
}

///|
/// None means unrestricted interpolation; Some(seconds) is the chosen gap cap.
pub fn AlignedTable::max_gap(self : AlignedTable) -> Double? {
  self.gap
}
