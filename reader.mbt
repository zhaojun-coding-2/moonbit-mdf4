///|
/// Read finalized MDF 4.10/4.11 fixed-record data. No repair of unfinished files.
#warnings("-result_error_return")
pub fn open(
  bytes : Bytes,
  limits~ : Limits = Limits::default(),
) -> Result[MdfFile, MdfError] {
  Ok(open_checked(bytes, limits)) catch {
    e => Err(e)
  }
}

///|
fn open_checked(bytes : Bytes, limits : Limits) -> MdfFile raise MdfError {
  if limits.max_output < 0 || limits.max_blocks < 1 || limits.max_samples < 0 {
    raise LimitExceeded("invalid limits")
  }
  span(bytes, 0, 64)
  if copy_bytes(bytes, 0, 7) == b"UnFinMF" {
    raise UnfinalizedFile
  }
  if copy_bytes(bytes, 0, 8) != b"MDF     " {
    corrupt("invalid file identifier")
  }
  let version = tx_version(bytes)
  if version != "4.10" && version != "4.11" {
    raise UnsupportedVersion(version)
  }
  let code = uint_le(bytes, 28, 2)
  if code != 410UL && code != 411UL {
    corrupt("ID binary version disagrees")
  }
  if (version == "4.10" && code != 410UL) ||
    (version == "4.11" && code != 411UL) {
    corrupt("ID version mismatch")
  }
  if uint_le(bytes, 60, 4) != 0UL {
    raise UnfinalizedFile
  }
  let hd = block(bytes, 64UL)
  expect(hd, "HD", 6, 32)
  let channels : Array[Channel] = []
  let groups : Array[Group] = []
  let seen : Array[UInt64] = [64UL]
  let mut dg_addr = hd.links[0]
  let mut total = 0
  while dg_addr != 0UL {
    track(seen, dg_addr, limits)
    let dg = block(bytes, dg_addr)
    expect(dg, "DG", 4, 8)
    let rid = u8(bytes, dg.data)
    if rid != 0 && rid != 1 && rid != 2 && rid != 4 && rid != 8 {
      corrupt("invalid record ID length")
    }
    let first = groups.length()
    let mut cg_addr = dg.links[1]
    while cg_addr != 0UL {
      track(seen, cg_addr, limits)
      let cg = block(bytes, cg_addr)
      expect(cg, "CG", 6, 32)
      let flags = uint_le(bytes, cg.data + 16, 2)
      if (flags & 1UL) != 0UL {
        raise UnsupportedFeature("VLSD channel group")
      }
      if (flags & 8UL) != 0UL {
        raise UnsupportedFeature("remote master group")
      }
      let size = small(
        uint_le(bytes, cg.data + 24, 4),
        limits.max_output,
        "record size",
      )
      let invalid = small(
        uint_le(bytes, cg.data + 28, 4),
        limits.max_output - size,
        "invalidation size",
      )
      let cycles = small(
        uint_le(bytes, cg.data + 8, 8),
        limits.max_samples - total,
        "sample count",
      )
      total += cycles
      let id = uint_le(bytes, cg.data, 8)
      for k in first..<groups.length() {
        if groups[k].record_id == id {
          corrupt("duplicate record ID")
        }
      }
      if rid < 8 && id >= 1UL << (rid * 8) && rid != 0 {
        corrupt("record ID out of range")
      }
      if size + invalid == 0 && cycles > 0 {
        corrupt("zero record size")
      }
      let gi = groups.length()
      groups.push({
        record_id: id,
        cycles,
        size,
        invalid_bytes: invalid,
        records: [],
      })
      read_channels(bytes, cg.links[1], gi, channels, seen, limits, 0)
      cg_addr = cg.links[0]
    }
    if rid == 0 && groups.length() - first > 1 {
      corrupt("multiple groups without record IDs")
    }
    let data : Array[Byte] = []
    collect_data(bytes, dg.links[2], data, [], limits)
    let raw = Bytes::from_array(data)
    let mut pos = 0
    while pos < raw.length() {
      let mut gi = first
      if rid > 0 {
        let id = uint_le(raw, pos, rid)
        pos += rid
        while gi < groups.length() && groups[gi].record_id != id {
          gi += 1
        }
      }
      if gi >= groups.length() {
        corrupt("unknown record ID or missing group")
      }
      let g = groups[gi]
      if g.records.length() >= g.cycles {
        corrupt("record count exceeds CG cycles")
      }
      g.records.push(copy_bytes(raw, pos, g.size + g.invalid_bytes))
      pos += g.size + g.invalid_bytes
    }
    for gi in first..<groups.length() {
      if groups[gi].records.length() != groups[gi].cycles {
        corrupt("CG cycles/record count mismatch")
      }
    }
    dg_addr = dg.links[0]
  }
  {
    bytes,
    version_: version,
    start_ns_: uint_le(bytes, hd.data, 8),
    channels_: channels,
    groups,
    limits,
  }
}

///|
fn tx_version(b : Bytes) -> String raise MdfError {
  @utf8.decode(b[8:12]) catch {
    _ => raise CorruptedBlock("invalid version text")
  }
}

///|
fn track(
  seen : Array[UInt64],
  address : UInt64,
  limits : Limits,
) -> Unit raise MdfError {
  if seen.contains(address) {
    corrupt("cyclic/reused topology link")
  }
  if seen.length() >= limits.max_blocks {
    raise LimitExceeded("topology block count")
  }
  seen.push(address)
}

///|
fn read_channels(
  bytes : Bytes,
  address : UInt64,
  gi : Int32,
  channels : Array[Channel],
  seen : Array[UInt64],
  limits : Limits,
  depth : Int32,
) -> Unit raise MdfError {
  if depth > 64 {
    raise LimitExceeded("channel composition depth")
  }
  let mut addr = address
  while addr != 0UL {
    track(seen, addr, limits)
    let cn = block(bytes, addr)
    expect(cn, "CN", 8, 72)
    let p = cn.data
    channels.push({
      name: tx(bytes, cn.links[2]),
      unit: tx(bytes, cn.links[6]),
      group: gi,
      address: addr,
      kind: u8(bytes, p),
      sync: u8(bytes, p + 1),
      data_type: u8(bytes, p + 2),
      bit_offset: u8(bytes, p + 3),
      byte_offset: small(
        uint_le(bytes, p + 4, 4),
        limits.max_output,
        "channel byte offset",
      ),
      bit_count: small(
        uint_le(bytes, p + 8, 4),
        limits.max_output,
        "channel bit count",
      ),
      flags: uint_le(bytes, p + 12, 4).to_uint(),
      invalid_bit: if (uint_le(bytes, p + 12, 4) & 2UL) == 0UL {
        0
      } else {
        small(uint_le(bytes, p + 16, 4), 2147483647, "invalid bit position")
      },
      conversion_address: cn.links[4],
    })
    if cn.links[1] != 0UL {
      let child = block(bytes, cn.links[1])
      if child.id == "CN" {
        read_channels(bytes, cn.links[1], gi, channels, seen, limits, depth + 1)
      } else {
        raise UnsupportedFeature("channel array/composition \{child.id}")
      }
    }
    addr = cn.links[0]
  }
}
