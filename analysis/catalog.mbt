///|
priv struct CatalogChannel {
  index : Int32
  group : Int32
  name : String
  unit : String
  channel_kind : Int32
  sync_type : Int32
  data_type : Int32
  bit_count : Int32
} derive(ToJson)

///|
priv struct ChannelCatalog {
  catalogue_version : String
  file_version : String
  start_ns : String
  channels : Array[CatalogChannel]
} derive(ToJson)

///|
/// List every channel in the same order used by read_channel and export indices.
/// Uses metadata only; listing does not certify sample/conversion support.
/// After opening a file, `println(@analysis.channel_catalog_json(file))` emits
/// the catalogue; example/catalog supplies a runnable duplicate-name example.
pub fn channel_catalog_json(file : @mdf.MdfFile) -> String {
  let channels : Array[CatalogChannel] = []
  for index, channel in file.channels() {
    channels.push({
      index,
      group: channel.group,
      name: channel.name,
      unit: channel.unit,
      channel_kind: channel.kind,
      sync_type: channel.sync,
      data_type: channel.data_type,
      bit_count: channel.bit_count,
    })
  }
  let catalog : ChannelCatalog = {
    catalogue_version: "mdf4.analysis.channels/1",
    file_version: file.version(),
    start_ns: file.start_ns().to_string(),
    channels,
  }
  @json.to_json(catalog).stringify()
}
