"""Owned duplicate-name/unit selection fixtures; no product parser or vendor data."""
from pathlib import Path
import struct, json, hashlib

p = Path(__file__).resolve().parents[1]
out = p / 'analysis/catalog_fixture'
out.mkdir(parents=True, exist_ok=True)
b = bytearray((p / 'testdata/unsorted.mf4').read_bytes())
assert hashlib.sha256(b).hexdigest() == '6349e3773fd46e58b94bfe54b555dd2286eec01097040cc74ba955e5ce1a2da1'

def block(a):
    n = struct.unpack_from('<Q', b, a + 16)[0]
    return list(struct.unpack_from('<' + 'Q' * n, b, a + 24)), a + 24 + 8 * n

def append(kind, links, payload):
    b.extend(b'\0' * (-len(b) % 8))
    a = len(b)
    b.extend(struct.pack('<4s4xQQ', kind, 24 + 8 * len(links) + len(payload), len(links)))
    b.extend(struct.pack('<' + 'Q' * len(links), *links))
    b.extend(payload)
    return a

def tx(s):
    data = s.encode('utf-8') + b'\0'
    data += b'\0' * (-len(data) % 8)
    return append(b'##TX', [], data)

hd, hdpos = block(64)
dg, _ = block(hd[0])
group, group_index, signal_addresses = dg[1], 0, []
name = tx('速度🚲')
while group:
    cg, _ = block(group)
    channel = cg[1]
    while channel:
        links, pos = block(channel)
        if b[pos] == 0:
            unit = tx('km/h' if group_index == 0 else 'm/s')
            struct.pack_into('<Q', b, channel + 24 + 2 * 8, name)
            struct.pack_into('<Q', b, channel + 24 + 6 * 8, unit)
            signal_addresses.append(channel)
        channel = links[0]
    group = cg[0]
    group_index += 1
struct.pack_into('<Q', b, hdpos, 2**64 - 1)
catalog = bytes(b)
cc = append(b'##CC', [0, 0, 0, 0], struct.pack('<BBHHHdd', 99, 0, 0, 0, 0, 0., 0.))
struct.pack_into('<Q', b, signal_addresses[0] + 24 + 4 * 8, cc)
files = {'catalog': catalog, 'unsupported': bytes(b)}
source = ['// Self-created MIT catalogue fixtures; validation/generate_catalog_fixture.py\n']
for name, data in files.items():
    (out / (name + '.mf4')).write_bytes(data)
    source.append('\n///|\npub fn ' + name + '() -> Bytes {\n  let parts : Array[Bytes] = [\n')
    for i in range(0, len(data), 256):
        source.append('    b"' + ''.join('\\x%02x' % v for v in data[i:i+256]) + '",\n')
    source.append('  ]\n  let bytes : Array[Byte] = []\n  for part in parts { for value in part { bytes.push(value) } }\n  Bytes::from_array(bytes)\n}\n')
(out / 'fixtures.mbt').write_text(''.join(source), encoding='utf-8')
(out / 'moon.pkg').write_text('', encoding='utf-8')
manifest = {'origin': 'Own MIT unsorted fixture; same records, Unicode duplicate names and distinct units; unsupported CC99 derivative',
            'base_sha256': '6349e3773fd46e58b94bfe54b555dd2286eec01097040cc74ba955e5ce1a2da1',
            'start_ns': str(2**64 - 1), 'names': ['time', '速度🚲', 'time', '速度🚲'],
            'selection': [{'index': 1, 'group': 0, 'unit': 'km/h'}, {'index': 3, 'group': 1, 'unit': 'm/s'}],
            'files': [{'name': name, 'sha256': hashlib.sha256(data).hexdigest(), 'bytes': len(data)} for name, data in files.items()]}
(out / 'manifest.json').write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
print(json.dumps(manifest))
