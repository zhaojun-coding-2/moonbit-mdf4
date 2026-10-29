"""Independent full typed/wire profile and actual summary file consumer.

Expected events/counts come from frozen original bytes and explicit physical
facts. Decimal point strings are checked by binary64 bits, including -0; no
particular shortest decimal spelling is used as a numerical oracle.
"""
import argparse
import copy
import hashlib
import json
import math
from pathlib import Path
import re
import struct
import subprocess

ROOT=Path(__file__).resolve().parents[1]
CASES=ROOT/'validation/profile-cases.json'
COUNT_KEYS=['sample_count','invalid_samples','finite_samples','nan_samples','positive_infinity_samples','negative_infinity_samples']
INTEGER_KEYS=['channel_index','group_index','master_channel_index',*COUNT_KEYS]


def sha(raw):return hashlib.sha256(raw).hexdigest()
def bits(value):return struct.pack('>d',value).hex()


def normalize(profile,wire=True):
    expected_keys={'profile_version','file_version','start_ns','channel_index','group_index','master_channel_index',
       'name','unit','master_unit','time_unit',*COUNT_KEYS,'numeric_kind_observed','strict_time_order','minimum','maximum'}
    assert type(profile) is dict and set(profile)==expected_keys
    for key in INTEGER_KEYS:assert type(profile[key]) is int and profile[key]>=0
    for key in ['numeric_kind_observed','strict_time_order']:assert type(profile[key]) is bool
    for key in ['profile_version','file_version','start_ns','name','unit','master_unit','time_unit']:assert type(profile[key]) is str
    assert profile['profile_version']=='mdf4.analysis.numeric-profile/1' and profile['time_unit']=='native_master_physical'
    assert re.fullmatch(r'0|[1-9][0-9]*',profile['start_ns']) and int(profile['start_ns'])<=2**64-1
    assert profile['sample_count']==sum(profile[k] for k in COUNT_KEYS[1:])
    assert profile['numeric_kind_observed']==(profile['sample_count']>0)
    result=copy.deepcopy(profile)
    for key in ['minimum','maximum']:
        point=profile[key]
        assert (point is not None)==(profile['finite_samples']>0)
        if point is None:continue
        assert type(point) is dict and type(point['record_index']) is int and 0<=point['record_index']<profile['sample_count']
        if wire:
            assert set(point)=={'record_index','time','value'}
            parsed=[]
            for field in ['time','value']:
                text=point[field]
                assert type(text) is str and re.fullmatch(r'-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?',text)
                value=float(text);assert math.isfinite(value);parsed.append(bits(value))
            result[key]={'record_index':point['record_index'],'time_bits':parsed[0],'value_bits':parsed[1]}
        else:
            assert set(point)=={'record_index','time_bits','value_bits'}
            for field in ['time_bits','value_bits']:
                assert re.fullmatch(r'[0-9a-f]{16}',point[field])
                assert math.isfinite(struct.unpack('>d',bytes.fromhex(point[field]))[0])
    return result


def example(path):
    cases=json.loads(CASES.read_bytes());actual=json.loads(path.read_bytes())
    assert len(actual)==len(cases)==19
    for case,out in zip(cases,actual):
        assert set(out)=={'name','error','typed','wire'} and out['name']==case['name']
        if case['stage']=='error':
            assert out['error']==case['expected_error'] and out['typed'] is None and out['wire'] is None
        else:
            assert out['error'] is None
            assert normalize(out['typed'],False)==normalize(out['wire'])==case['expected'],case['name']
    print(json.dumps({'status':'pass','successCases':12,'profileErrors':7,'sourceRecordOccurrences':42,
                      'oracleSHA256':sha(CASES.read_bytes()),'outputSHA256':sha(path.read_bytes())}))


def files(binary,out):
    out.mkdir(parents=True,exist_ok=False)
    cases=json.loads(CASES.read_bytes());commands=[];checked=[]
    inputs={}
    for case in cases:
        p=ROOT/case['source'];raw=p.read_bytes()
        assert sha(raw)==case['sourceIdentity']['sha256'] and len(raw)==case['sourceIdentity']['bytes']
        inputs[case['source']]={'path':str(p),'bytes':len(raw),'sha256':sha(raw)}
    (out/'inputs-and-expected.json').write_text(json.dumps({'sources':inputs,'cases':cases},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    def invoke(name,args):
        argv=['node',str(binary),*map(str,args)];cp=subprocess.run(argv,cwd=ROOT,capture_output=True)
        (out/(name+'.stdout')).write_bytes(cp.stdout);(out/(name+'.stderr')).write_bytes(cp.stderr)
        commands.append({'name':name,'argv':argv,'cwd':str(ROOT),'exit':cp.returncode,'stdoutSHA256':sha(cp.stdout),'stderrSHA256':sha(cp.stderr)})
        (out/'commands.json').write_text(json.dumps(commands,indent=2)+'\n',encoding='utf-8')
        return cp
    for case in cases:
        cp=invoke(case['name'],[ROOT/case['source'],case['index'],'--numeric'])
        if case['stage']=='success':
            assert cp.returncode==0 and cp.stderr==b'' and cp.stdout.endswith(b'\n'),(case['name'],cp.stderr)
            assert normalize(json.loads(cp.stdout))==case['expected'],case['name']
        else:
            assert cp.returncode!=0 and cp.stdout==b'' and case['expected_error'].encode() in cp.stderr,(case['name'],cp.stderr)
        checked.append({'name':case['name'],'stage':case['stage'],'stdoutSHA256':sha(cp.stdout),'stderrSHA256':sha(cp.stderr)})
    legacy=invoke('legacy-summary',[ROOT/'analysis/catalog_fixture/catalog.mf4',1])
    assert legacy.returncode==0 and legacy.stderr==b''
    assert json.loads(legacy.stdout)==json.loads((ROOT/'validation/profile-legacy-summary.json').read_bytes())
    extra=[('bad-flag',[ROOT/'analysis/catalog_fixture/catalog.mf4',1,'--unknown'],b'Usage:'),
           ('bad-index',[ROOT/'analysis/catalog_fixture/catalog.mf4','true','--numeric'],b'Channel index must be an integer'),
           ('missing-file',[out/'absent.mf4',1,'--numeric'],b'Cannot open MDF input:'),('usage',[],b'Usage:')]
    for name,args,fragment in extra:
        cp=invoke(name,args);assert cp.returncode!=0 and cp.stdout==b'' and fragment in cp.stderr,name
    assert len(commands)==24
    assert all(sha((ROOT/name).read_bytes())==pin['sha256'] for name,pin in inputs.items())
    manifest={'status':'pass','compiled':{'path':str(binary),'bytes':binary.stat().st_size,'sha256':sha(binary.read_bytes())},
              'oracleSHA256':sha(CASES.read_bytes()),'successCases':12,'profileErrors':7,'entryIOErrors':4,'legacySummaryControls':1,
              'actualNodeCalls':24,'sourceRecordOccurrences':42,'completeCases':checked,'commands':commands,'sources':inputs,'sourceInputsUnchanged':True}
    (out/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'status':'pass','successCases':12,'profileErrors':7,'entryIOErrors':4,'legacySummaryControls':1,'actualNodeCalls':24,
                      'manifestSHA256':sha((out/'manifest.json').read_bytes())}))


def main():
    p=argparse.ArgumentParser(description=__doc__);sub=p.add_subparsers(dest='mode',required=True)
    a=sub.add_parser('example');a.add_argument('output',type=Path)
    a=sub.add_parser('files');a.add_argument('binary',type=Path);a.add_argument('out',type=Path)
    args=p.parse_args()
    if args.mode=='example':example(args.output.resolve())
    else:files(args.binary.resolve(),args.out.resolve())


if __name__=='__main__':main()
