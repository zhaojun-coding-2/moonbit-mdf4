///|
// Node handles only the saved-file protocol, hashing and I/O. It passes the
// exact source buffer to the MoonBit collector; no decoder is duplicated here.
extern "js" fn run_file_cli(
  collect : (Bytes, FixedArray[Int32]) -> FixedArray[String],
) -> Unit =
  #|(collect) => {
  #|  try {
  #|    const fs = require('node:fs');
  #|    const crypto = require('node:crypto');
  #|    const {TextDecoder} = require('node:util');
  #|    const args = process.argv.slice(2);
  #|    if (args.length !== 4 || args[2] !== '--receipt')
  #|      throw new Error('Usage: native-handoff SOURCE.mf4 REQUEST.json --receipt NEW_PATH');
  #|    const exact = (value, fields, label) => {
  #|      if (value === null || typeof value !== 'object' || Array.isArray(value) ||
  #|          Object.keys(value).sort().join(',') !== fields.slice().sort().join(','))
  #|        throw new Error(label + ': invalid fields');
  #|    };
  #|    const decimal = (value, label, maximum) => {
  #|      if (typeof value !== 'string' || !/^(0|[1-9][0-9]*)$/.test(value) ||
  #|          (maximum !== undefined && BigInt(value) > maximum))
  #|        throw new Error(label + ': expected canonical nonnegative decimal string');
  #|    };
  #|    const fingerprint = bytes => ({bytes:String(bytes.byteLength),
  #|      sha256:crypto.createHash('sha256').update(bytes).digest('hex')});
  #|    const requestBytes = fs.readFileSync(args[1]);
  #|    const request = JSON.parse(new TextDecoder('utf-8', {fatal:true}).decode(requestBytes));
  #|    exact(request, ['request_version','source','windows'], 'request');
  #|    if (request.request_version !== 'mdf4.native-window.request/1')
  #|      throw new Error('request: unsupported version');
  #|    exact(request.source, ['bytes','sha256'], 'source');
  #|    decimal(request.source.bytes, 'source.bytes');
  #|    if (typeof request.source.sha256 !== 'string' || !/^[0-9a-f]{64}$/.test(request.source.sha256))
  #|      throw new Error('source.sha256: expected lowercase SHA-256');
  #|    if (!Array.isArray(request.windows)) throw new Error('windows: expected array');
  #|    if (request.windows.length > 4096) throw new Error('handoff window limit exceeded');
  #|    let records = 0;
  #|    const specs = [];
  #|    for (const [ordinal, w] of request.windows.entries()) {
  #|      const fields = ['channel_index','expected_group','start_record','record_count'];
  #|      exact(w, fields, 'window ' + ordinal);
  #|      for (const field of fields) {
  #|        decimal(w[field], 'window ' + ordinal + '.' + field, 2147483647n);
  #|        specs.push(Number(w[field]));
  #|      }
  #|      records += Number(w.record_count);
  #|      if (records > 1000000) throw new Error('handoff returned-record limit exceeded');
  #|    }
  #|    const sourceBytes = fs.readFileSync(args[0]);
  #|    const source = fingerprint(sourceBytes);
  #|    if (source.bytes !== request.source.bytes || source.sha256 !== request.source.sha256)
  #|      throw new Error('source identity mismatch');
  #|    const collected = collect(sourceBytes, specs);
  #|    if (collected.length !== 1) throw new Error(collected[1]);
  #|    // Explicit versioned field order, compact UTF-8 plus exactly one LF.
  #|    const keys = ['result_version','file','version','start_ns','windows',
  #|      'ordinal','channel_index','group_index','master_channel_index','name','unit',
  #|      'master_unit','start_record','record_count','time_unit','time_bits','raw','values',
  #|      'valid','kind','decimal','bits','text','hex'];
  #|    const resultBytes = Buffer.from(JSON.stringify(JSON.parse(collected[0]), keys) + '\n', 'utf8');
  #|    const receipt = {receipt_version:'mdf4.native-window.receipt/1', source,
  #|      request:fingerprint(requestBytes), result:{...fingerprint(resultBytes),encoding:'UTF-8'},
  #|      result_version:'mdf4.native-window.result/1', window_count:String(request.windows.length),
  #|      returned_record_count:String(records)};
  #|    fs.writeFileSync(args[3], JSON.stringify(receipt) + '\n', {encoding:'utf8',flag:'wx'});
  #|    // A receipt binds intended stdout bytes. Only the independent saved-file
  #|    // receiver can confirm that a shell/pipe saved all of them correctly.
  #|    let offset = 0;
  #|    while (offset < resultBytes.length) {
  #|      const written = fs.writeSync(1, resultBytes, offset, resultBytes.length - offset);
  #|      if (written <= 0) throw new Error('stdout write did not advance');
  #|      offset += written;
  #|    }
  #|  } catch (error) {
  #|    process.stderr.write('native-handoff: ' + error.message + '\n');
  #|    process.exitCode = 1;
  #|  }
  #|}
