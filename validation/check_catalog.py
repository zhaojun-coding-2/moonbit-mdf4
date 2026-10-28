"""Actual catalogue -> index selection -> CSV/receipt consumer, standard Python only.

Usage: check_catalog.py COMPILED_CHANNELS_JS COMPILED_EXPORT_JS NEW_CAPTURE_DIRECTORY
"""
from pathlib import Path
import csv
import hashlib
import io
import json
import subprocess
import sys

p = Path(__file__).resolve().parents[1]
channels_js, export_js, out = map(lambda s: Path(s).resolve(), sys.argv[1:])
out.mkdir(parents=True, exist_ok=False)
fixture = p / 'analysis/catalog_fixture/catalog.mf4'
unsupported = p / 'analysis/catalog_fixture/unsupported.mf4'
origin = str(2**64 - 1)
expected_rows = [
    {'index': 0, 'group': 0, 'name': 'time', 'unit': '', 'channel_kind': 2, 'sync_type': 1, 'data_type': 4, 'bit_count': 64},
    {'index': 1, 'group': 0, 'name': '速度🚲', 'unit': 'km/h', 'channel_kind': 0, 'sync_type': 0, 'data_type': 2, 'bit_count': 16},
    {'index': 2, 'group': 1, 'name': 'time', 'unit': '', 'channel_kind': 2, 'sync_type': 1, 'data_type': 4, 'bit_count': 64},
    {'index': 3, 'group': 1, 'name': '速度🚲', 'unit': 'm/s', 'channel_kind': 0, 'sync_type': 0, 'data_type': 2, 'bit_count': 16},
]
expected = {'catalogue_version': 'mdf4.analysis.channels/1', 'file_version': '4.10', 'start_ns': origin, 'channels': expected_rows}

def invoke(name, executable, args):
    result = subprocess.run(['node', str(executable), *map(str, args)], capture_output=True)
    (out / (name + '.stdout')).write_bytes(result.stdout)
    (out / (name + '.stderr')).write_bytes(result.stderr)
    return result

def catalogue(name, file, reference):
    result = invoke(name, channels_js, [file])
    assert result.returncode == 0 and result.stderr == b'', result.stderr
    data = json.loads(result.stdout.decode('utf-8'))
    assert data == reference
    (out / (name + '.catalog.json')).write_bytes(result.stdout)
    return data

normal = catalogue('normal', fixture, expected)
other = catalogue('unsupported', unsupported, expected)
empty_file = out / 'empty.mf4'
data = bytearray(fixture.read_bytes())
data[88:96] = b'\0' * 8
empty_file.write_bytes(data)
catalogue('empty', empty_file, {**expected, 'channels': []})
unicode_file = out / '自有 测量.mf4'
unicode_file.write_bytes(fixture.read_bytes())
catalogue('unicode-path', unicode_file, expected)

def select(catalogue, unit, group):
    matches = [row for row in catalogue['channels'] if row['name'] == '速度🚲' and row['unit'] == unit and row['group'] == group]
    assert len(matches) == 1
    return matches[0]['index']

ms, kmh = select(normal, 'm/s', 1), select(normal, 'km/h', 0)
assert (ms, kmh) == (3, 1)
exports = []
def export(name, source, grid, selections, expected_csv):
    receipt = out / (name + '.receipt.json')
    args = [source, grid]
    for label, index in selections:
        args += [label, str(index), 'previous']
    args += ['--receipt', receipt]
    result = invoke(name, export_js, args)
    assert result.returncode == 0 and result.stderr == b'', result.stderr
    rows = list(csv.reader(io.StringIO(result.stdout.decode('utf-8'), newline=''), strict=True))
    assert rows == expected_csv
    saved = out / (name + '.csv')
    saved.write_bytes(result.stdout)
    meta = json.loads(receipt.read_text(encoding='utf-8'))
    assert [c['channel'] for c in meta['table']['columns']] == [index for _, index in selections]
    assert [c['source_name'] for c in meta['table']['columns']] == ['速度🚲'] * len(selections)
    assert [c['interpolation'] for c in meta['table']['columns']] == ['previous'] * len(selections)
    assert [c['unit'] for c in meta['table']['columns']] == ['m/s', 'km/h'][:len(selections)]
    check = subprocess.run([sys.executable, str(p / 'validation/verify_export.py'), str(source), str(saved), str(receipt)], capture_output=True)
    assert check.returncode == 0, check.stderr
    verified = json.loads(check.stdout)
    assert verified['status'] == 'pass'
    (out / (name + '.verified.json')).write_bytes(check.stdout)
    exports.append(verified)

export('chosen', fixture, '0,0.25,0.5,0.75,1', [('ms', ms), ('kmh', kmh)], [
    ['start_ns', 'time_s', 'ms [m/s]', 'ms [m/s]__valid', 'kmh [km/h]', 'kmh [km/h]__valid'],
    [origin, '0', '', 'false', '-3', 'true'],
    [origin, '0.25', '42', 'true', '-3', 'true'],
    [origin, '0.5', '42', 'true', '-3', 'true'],
    [origin, '0.75', '-99', 'true', '-3', 'true'],
    [origin, '1', '', 'false', '', 'false'],
])
export('chosen-unsupported', unsupported, '0.25,0.5,0.75', [('ms', select(other, 'm/s', 1))], [
    ['start_ns', 'time_s', 'ms [m/s]', 'ms [m/s]__valid'],
    [origin, '0.25', '42', 'true'],
    [origin, '0.5', '42', 'true'],
    [origin, '0.75', '-99', 'true'],
])

malformed = out / 'malformed.mf4'
malformed.write_bytes(b'not an MDF file')
errors = [[], [fixture, 'extra'], [out / 'absent.mf4'], [out], [malformed]]
for i, args in enumerate(errors):
    result = invoke('error-' + str(i), channels_js, args)
    assert result.returncode != 0 and result.stdout == b'' and result.stderr.endswith(b'\n')

print(json.dumps({'status': 'pass', 'catalogues': 4, 'catalogue_error_paths': len(errors), 'selected_exports': len(exports),
                  'complete_csv_rows': sum(row['rows'] for row in exports), 'saved_receipts_verified_by_cli': len(exports),
                  'selected_indices': {'m_s': ms, 'km_h': kmh},
                  'compiled_channels_sha256': hashlib.sha256(channels_js.read_bytes()).hexdigest(),
                  'compiled_export_sha256': hashlib.sha256(export_js.read_bytes()).hexdigest(),
                  'reference': 'Literal ordered metadata/CSV expectations, independently checked asammdf fixture metadata, actual saved-byte verifier'}))
