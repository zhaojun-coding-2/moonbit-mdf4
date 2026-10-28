"""Catalogue -> selected summary -> explicit endpoint-grid CSV/receipt consumer.

Usage: check_summary.py SUMMARY_JS CHANNELS_JS EXPORT_JS NEW_CAPTURE_DIRECTORY
Standard Python/Node only. ALL_INVALID masks use literal flags, not asammdf's discrepant bitmap.
"""
from pathlib import Path
import csv, hashlib, io, json, subprocess, sys

p = Path(__file__).resolve().parents[1]
summary_js, channels_js, export_js, out = map(lambda s: Path(s).resolve(), sys.argv[1:])
out.mkdir(parents=True, exist_ok=False)
source = p / 'analysis/summary_fixture/calibrated.mf4'
origin = str(2**64-1)

def invoke(name, executable, args):
    cp = subprocess.run(['node', str(executable), *map(str,args)], capture_output=True)
    (out/(name+'.stdout')).write_bytes(cp.stdout)
    (out/(name+'.stderr')).write_bytes(cp.stderr)
    return cp

cat = invoke('catalogue', channels_js, [source])
assert cat.returncode == 0 and cat.stderr == b''
catalogue = json.loads(cat.stdout)
assert catalogue['catalogue_version'] == 'mdf4.analysis.channels/1' and len(catalogue['channels']) == 4
matches = [c for c in catalogue['channels'] if c['name']=='速度🚲' and c['group']==1 and c['unit']=='m/s']
assert len(matches)==1 and matches[0]['index']==3 and matches[0]['data_type']==2 and matches[0]['bit_count']==16
chosen = matches[0]['index']

def expected(index=3, group=1, name='速度🚲', unit='m/s', count=2, valid=2, kinds=None,
             first='10.5', last='11.5', ordered=True, version='4.10', start=origin):
    return {'summary_version':'mdf4.analysis.channel-summary/1','file_version':version,'start_ns':start,
            'index':index,'group':group,'name':name,'unit':unit,'sample_count':count,
            'valid_samples':valid,'invalid_samples':count-valid,'value_kinds':['label'] if kinds is None else kinds,
            'first_time':first,'last_time':last,'strict_time_order':ordered}

summaries = {}
def inspect(name, file, index, reference):
    cp = invoke(name, summary_js, [file,index])
    assert cp.returncode==0 and cp.stderr==b'', cp.stderr
    result = json.loads(cp.stdout.decode('utf-8'))
    assert result==reference, (name,result,reference)
    (out/(name+'.summary.json')).write_bytes(cp.stdout)
    summaries[name]=result
    return result

state = inspect('calibrated', source, chosen, expected())
inspect('numeric', source, 1, expected(index=1,group=0,unit='km/h',valid=1,kinds=['number'],first='0',last='1'))
inspect('all_invalid', p/'analysis/summary_fixture/all_invalid.mf4', chosen, expected(valid=0))
inspect('reversed', p/'analysis/summary_fixture/reversed.mf4', chosen, expected(first='11.5',last='10.5',ordered=False))
inspect('empty', p/'analysis/fixture/empty.mf4', 1,
        expected(index=1,group=0,name='identity',unit='u',count=0,valid=0,kinds=[],first=None,last=None,version='4.11',start='1793120324061712896'))
single_file = p/'analysis/fixture/single.mf4'
single = inspect('single', single_file, 1,
        expected(index=1,group=0,name='identity',unit='u',count=1,valid=1,kinds=['number'],first='-0',last='-0',version='4.11',start='1793120324061712896'))
assert state['value_kinds']==['label']  # raw signed-integer storage does not imply a numeric physical value.

def endpoint_grid(summary):
    # This consumer explicitly chooses endpoints; it does not reconstruct a uniform/native full raster.
    assert summary['strict_time_order']
    if summary['sample_count']==0: return []
    if summary['sample_count']==1: return [summary['first_time']]
    return [summary['first_time'],summary['last_time']]

exports=[]
def export(name, file, summary, alias, reference):
    grid=endpoint_grid(summary)
    receipt=out/(name+'.receipt.json')
    cp=invoke(name,export_js,[file,','.join(grid),alias,summary['index'],'previous','--receipt',receipt])
    assert cp.returncode==0 and cp.stderr==b'',cp.stderr
    rows=list(csv.reader(io.StringIO(cp.stdout.decode('utf-8'),newline=''),strict=True))
    assert rows==reference
    saved=out/(name+'.csv');saved.write_bytes(cp.stdout)
    meta=json.loads(receipt.read_text(encoding='utf-8'))
    assert meta['table']['columns'][0]['channel']==summary['index']
    assert meta['table']['columns'][0]['source_name']==summary['name'] and meta['table']['columns'][0]['unit']==summary['unit']
    assert meta['table']['columns'][0]['valid_value_kinds']==summary['value_kinds']
    assert meta['table']['first_time']==grid[0] and meta['table']['last_time']==grid[-1]
    check=subprocess.run([sys.executable,str(p/'validation/verify_export.py'),str(file),str(saved),str(receipt)],capture_output=True)
    assert check.returncode==0,check.stderr
    verified=json.loads(check.stdout);assert verified['status']=='pass'
    (out/(name+'.verified.json')).write_bytes(check.stdout);exports.append(verified)

export('state-endpoints',source,state,'state',[
    ['start_ns','time_s','state [m/s]','state [m/s]__valid'],
    [origin,'10.5','前进','true'],[origin,'11.5','倒车','true']])
export('signed-zero',single_file,single,'value',[
    ['start_ns','time_s','value [u]','value [u]__valid'],
    ['1793120324061712896','-0','5e-324','true']])

malformed=out/'malformed.mf4';malformed.write_bytes(b'not MDF')
errors=[([source],b'Usage'),([source,3,'extra'],b'Usage'),([source,'no'],b'integer'),
        ([source,-1],b'ChannelNotFound'),([source,4],b'ChannelNotFound'),
        ([p/'analysis/catalog_fixture/unsupported.mf4',1],b'UnsupportedConversion(99)'),
        ([malformed,3],b'Cannot open'),([out/'absent.mf4',3],b'Cannot open')]
for i,(args,detail) in enumerate(errors):
    cp=invoke('error-'+str(i),summary_js,args)
    assert cp.returncode!=0 and cp.stdout==b'' and detail in cp.stderr and cp.stderr.endswith(b'\n')

print(json.dumps({'status':'pass','catalogues':1,'summaries':len(summaries),'summary_error_paths':len(errors),
                  'selected_exports':len(exports),'complete_csv_rows':sum(x['rows'] for x in exports),
                  'saved_receipts_verified_by_cli':len(exports),'selected_index':chosen,
                  'compiled_summary_sha256':hashlib.sha256(summary_js.read_bytes()).hexdigest(),
                  'compiled_channels_sha256':hashlib.sha256(channels_js.read_bytes()).hexdigest(),
                  'compiled_export_sha256':hashlib.sha256(export_js.read_bytes()).hexdigest(),
                  'reference':'Literal full-object/CSV expectations; external physical readback except explicit ALL_INVALID-mask reference; actual saved-byte verifier'}))
