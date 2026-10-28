///|
pub(all) suberror MdfError {
  CorruptedBlock(String)
  UnfinalizedFile
  UnsupportedVersion(String)
  UnsupportedFeature(String)
  UnsupportedConversion(Int32)
  InvalidBitField
  InvalidFormula(String)
  InvalidTime(String)
  ChannelNotFound(String)
  AmbiguousChannel(String)
  LimitExceeded(String)
} derive(Debug, Eq)

///|
pub(all) struct Limits {
  max_output : Int32
  max_blocks : Int32
  max_samples : Int32
} derive(Debug)

///|
pub fn Limits::default() -> Limits {
  { max_output: 67108864, max_blocks: 100000, max_samples: 1000000, }
}

///|
pub(all) enum RawValue {
  Unsigned(UInt64)
  Signed(Int64)
  Real(Double)
  Octets(Bytes)
  Text(String)
} derive(Debug, Eq)

///|
pub(all) enum Value {
  Number(Double)
  Label(String)
  Data(Bytes)
} derive(Debug, Eq)

///|
pub(all) struct Channel {
  name : String
  unit : String
  group : Int32
  address : UInt64
  kind : Int32
  sync : Int32
  data_type : Int32
  byte_offset : Int32
  bit_offset : Int32
  bit_count : Int32
  flags : UInt32
  invalid_bit : Int32
  conversion_address : UInt64
} derive(Debug)

///|
pub(all) struct Series {
  name : String
  unit : String
  timestamps : Array[Double]
  values : Array[Value]
  valid : Array[Bool]
} derive(Debug)

///|
pub(all) enum Interpolation {
  Previous
  Linear
} derive(Debug, Eq)

///|
struct Group {
  record_id : UInt64
  cycles : Int32
  size : Int32
  invalid_bytes : Int32
  records : Array[Bytes]
}

///|
pub struct MdfFile {
  bytes : Bytes
  version_ : String
  start_ns_ : UInt64
  channels_ : Array[Channel]
  groups : Array[Group]
  limits : Limits
}

///|
pub fn MdfFile::version(self : MdfFile) -> String {
  self.version_
}

///|
pub fn MdfFile::start_ns(self : MdfFile) -> UInt64 {
  self.start_ns_
}

///|
pub fn MdfFile::channels(self : MdfFile) -> Array[Channel] {
  self.channels_.copy()
}

///|
fn corrupt(message : String) -> Unit raise MdfError {
  raise CorruptedBlock(message)
}

///|
fn finite(x : Double) -> Bool {
  !x.is_nan() && !x.is_inf()
}
