"""Independent complete interpolation regression; standard Python only.

The finite oracle is exact Fraction arithmetic over frozen binary64 inputs.
Compatibility controls are explicit literals. No MDF runtime/reference
implementation supplies the expected answers.
"""
import argparse
import csv
import hashlib
import io
import json
from pathlib import Path
import struct
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[1]


def sha(raw):return hashlib.sha256(raw).hexdigest()
def bits(value):return struct.pack('>d',float(value)).hex()
def value(hex):return struct.unpack('>d',bytes.fromhex(hex))[0]


def example(path):
    cases=json.loads((ROOT/'validation/interpolation-cases.json').read_bytes())
    expected=[c['expected'] for c in cases]
    actual=json.loads(path.read_bytes())
    assert actual==expected, 'complete public conversion/Linear/Previous/mask output differs from the independent full oracle'
    print(json.dumps({'status':'pass','cases':len(cases),'points':sum(len(c['queries']) for c in cases),
                      'oracleSHA256':sha((ROOT/'validation/interpolation-cases.json').read_bytes()),'actualOutputSHA256':sha(path.read_bytes())}))


def files(exporter,inspector,out):
    out.mkdir(parents=True,exist_ok=False)
    descriptors=json.loads((ROOT/'validation/interpolation-files.json').read_bytes())
    commands=[]
    checked=[]
    def run(name,argv):
        cp=subprocess.run(list(map(str,argv)),cwd=ROOT,capture_output=True)
        (out/(name+'.stdout')).write_bytes(cp.stdout);(out/(name+'.stderr')).write_bytes(cp.stderr)
        commands.append({'name':name,'argv':list(map(str,argv)),'cwd':str(ROOT),'exit':cp.returncode,
                         'stdoutSHA256':sha(cp.stdout),'stderrSHA256':sha(cp.stderr)})
        (out/'commands.json').write_text(json.dumps(commands,indent=2)+'\n',encoding='utf-8')
        assert cp.returncode==0 and cp.stderr==b'', (name,cp.stderr)
        return cp.stdout
    expected_inputs=[]
    for desc in descriptors:
        path=ROOT/('validation/interpolation-'+desc['name']+'.mf4')
        raw=path.read_bytes()
        assert sha(raw)==desc['source']['sha256'] and len(raw)==desc['source']['bytes']
        assert raw[8:16].hex()==desc['actual_header_hex']
        assert [raw[o:o+8][::-1].hex() for o in [1233,1257]]==desc['expected_raw']
        expected_inputs.append({'path':str(path),'bytes':len(raw),'sha256':sha(raw),'independentExpected':desc})
    # The complete file inputs and expectation descriptors are saved before use.
    (out/'inputs-and-expected.json').write_text(json.dumps(expected_inputs,indent=2)+'\n',encoding='utf-8')
    for desc in descriptors:
        source=ROOT/('validation/interpolation-'+desc['name']+'.mf4')
        if desc['mode']=='inspect':
            raw=run(desc['name'],['node',inspector,source,'--index','0'])
            actual=json.loads(raw)
            assert set(actual)=={'name','unit','raw','timestamps','valid','values'}
            assert actual['name']==desc['name_expected'] and actual['unit']==desc['unit'] and actual['valid']==desc['valid']
            assert all(type(x) is str for x in actual['raw'])
            assert [bits(float(x)) for x in actual['raw']]==desc['expected_raw']
            assert [bits(x) for x in actual['timestamps']]==desc['expected_times']
            assert [bits(x) for x in actual['values']]==desc['expected_values']
            checked.append({'name':desc['name'],'outputSHA256':sha(raw),'fullJSONCompared':True})
            continue
        grid=[value(h) for h in desc['grid']]
        raster=out/(desc['name']+'.raster.json')
        raster.write_text(json.dumps([repr(q) for q in grid])+'\n',encoding='utf-8')
        for gap in ([False,True] if desc['name']=='linear-left' else [False]):
            name=desc['name']+('-gap' if gap else '')
            receipt=out/(name+'.receipt.json')
            argv=['node',exporter,source,'@'+str(raster),'clock','0','linear']
            if gap:argv+=['--max-gap','0']
            argv+=['--receipt',receipt]
            raw=run(name,argv)
            saved=out/(name+'.csv');saved.write_bytes(raw)
            rows=list(csv.reader(io.StringIO(raw.decode('utf-8'),newline=''),strict=True))
            assert rows[0]==['start_ns','time_s','clock','clock__valid'] and len(rows)==4
            flags=[True,not gap,True]
            for i,row in enumerate(rows[1:]):
                assert len(row)==4 and row[0]==desc['start_ns'] and bits(float(row[1]))==desc['grid'][i]
                assert row[3]==str(flags[i]).lower()
                if flags[i]:assert bits(float(row[2]))==desc['grid'][i]
                else:assert row[2]==''
            table={'schema_version':'mdf4.analysis.schema/1','start_ns':desc['start_ns'],'row_count':3,
                   'origin_header':'start_ns','time_header':'time_s','max_gap_seconds':'0' if gap else None,
                   'first_time':rows[1][1],'last_time':rows[-1][1],
                   'columns':[{'channel':0,'label':'clock','source_name':'time','unit':'','interpolation':'linear',
                               'value_header':'clock','validity_header':'clock__valid','valid_rows':sum(flags),
                               'invalid_rows':3-sum(flags),'valid_value_kinds':['number']}]}
            meta=json.loads(receipt.read_bytes())
            assert meta=={'receipt_version':'mdf4.analysis.receipt/1','source':{'sha256':sha(source.read_bytes()),'bytes':len(source.read_bytes())},
                         'csv':{'sha256':sha(raw),'bytes':len(raw),'encoding':'UTF-8','newline':'CRLF'},'table':table}
            verified=json.loads(run(name+'-receiver',[sys.executable,'-B',ROOT/'validation/verify_export.py',source,saved,receipt]))
            assert verified['status']=='pass'
            checked.append({'name':name,'outputSHA256':sha(raw),'receiptSHA256':sha(receipt.read_bytes()),'fullRows':3,
                            'fullReceiptCompared':True,'independentSavedReceiver':verified})
    assert len(checked)==4
    manifest={'status':'pass','cases':checked,'commands':commands,'actualNodeCalls':sum(c['argv'][0]=='node' for c in commands),
              'completeCSVRows':sum(c.get('fullRows',0) for c in checked),'exporter':{'path':str(exporter),'sha256':sha(exporter.read_bytes())},
              'inspector':{'path':str(inspector),'sha256':sha(inspector.read_bytes())},'originalInputs':expected_inputs}
    (out/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'status':'pass','fileCases':len(checked),'completeCSVRows':manifest['completeCSVRows'],'actualNodeCalls':manifest['actualNodeCalls'],
                      'manifestSHA256':sha((out/'manifest.json').read_bytes())}))


def main():
    p=argparse.ArgumentParser(description=__doc__)
    sub=p.add_subparsers(dest='mode',required=True)
    a=sub.add_parser('example');a.add_argument('output',type=Path)
    a=sub.add_parser('files');a.add_argument('exporter',type=Path);a.add_argument('inspector',type=Path);a.add_argument('out',type=Path)
    args=p.parse_args()
    if args.mode=='example':example(args.output.resolve())
    else:files(args.exporter.resolve(),args.inspector.resolve(),args.out.resolve())


if __name__=='__main__':main()
