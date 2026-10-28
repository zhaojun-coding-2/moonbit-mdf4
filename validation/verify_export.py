"""Verify an MDF CSV receipt against exact local source/output bytes and CSV structure.

Usage: python validation/verify_export.py SOURCE_MF4 EXPORTED_CSV RECEIPT_JSON
This verifies fingerprints and receipt/CSV consistency; it does not reparse MDF or authenticate a signer.
"""
from pathlib import Path
import sys,json,hashlib,csv,io,math

def require(condition,message):
 if not condition:raise ValueError(message)

def verify(source_bytes,csv_bytes,receipt):
 require(receipt.get('receipt_version')=='mdf4.analysis.receipt/1','unknown receipt version')
 for key,data in [('source',source_bytes),('csv',csv_bytes)]:
  info=receipt.get(key,{})
  require(info.get('bytes')==len(data),key+' byte length mismatch')
  require(info.get('sha256')==hashlib.sha256(data).hexdigest(),key+' SHA-256 mismatch')
 require(receipt['csv'].get('encoding')=='UTF-8' and receipt['csv'].get('newline')=='CRLF','unknown CSV representation')
 require(csv_bytes.endswith(b'\r\n'),'CSV does not end in CRLF')
 # A legal exported text field can exceed Python csv's default ceiling.
 # Bound this parse by the actual verified file, then restore the caller's setting.
 previous_field_limit=csv.field_size_limit()
 try:
  csv.field_size_limit(max(previous_field_limit,len(csv_bytes)))
  rows=list(csv.reader(io.StringIO(csv_bytes.decode('utf-8'),newline=''),strict=True))
 finally:
  csv.field_size_limit(previous_field_limit)
 table=receipt.get('table',{})
 require(table.get('schema_version')=='mdf4.analysis.schema/1','unknown table schema version')
 columns=table.get('columns',[])
 expected=[table.get('origin_header'),table.get('time_header')]
 require(expected==['start_ns','time_s'],'unknown metadata headers')
 for c in columns:
  require(isinstance(c.get('channel'),int) and c['channel']>=0,'invalid channel index')
  require(c.get('interpolation') in ['previous','linear'],'invalid interpolation policy')
  header=c['label']+(' ['+c['unit']+']' if c['unit'] else '')
  require(c.get('value_header')==header and c.get('validity_header')==header+'__valid','column/header mismatch')
  require(c.get('valid_value_kinds')==[k for k in ['number','label','data'] if k in c.get('valid_value_kinds',[])],'invalid observed kind list')
  expected.extend([header,header+'__valid'])
 require(rows and rows[0]==expected and len(set(expected))==len(expected),'CSV header mismatch')
 require(isinstance(table.get('row_count'),int) and table['row_count']==len(rows)-1,'row count mismatch')
 require(isinstance(table.get('start_ns'),str) and 0<=int(table['start_ns'])<2**64,'invalid exact origin')
 cap=table.get('max_gap_seconds')
 require('max_gap_seconds' in table and (cap is None or isinstance(cap,str) and math.isfinite(float(cap)) and float(cap)>=0),'invalid gap metadata')
 require('first_time' in table and 'last_time' in table,'missing time-bound metadata')
 valid_counts=[0]*len(columns);last=None
 for row in rows[1:]:
  require(len(row)==len(expected),'CSV row width mismatch')
  require(row[0]==table['start_ns'],'row origin mismatch')
  time=float(row[1]);require(math.isfinite(time) and (last is None or time>last),'invalid time order');last=time
  for i,c in enumerate(columns):
   value,valid=row[2+2*i:4+2*i]
   require(valid in ['true','false'],'invalid validity token')
   if valid=='false':require(value=='','invalid value field must be blank');continue
   valid_counts[i]+=1;kinds=c['valid_value_kinds'];require(kinds,'missing observed kind for valid values')
   if kinds==['number']:
    try:float(value)
    except ValueError:raise ValueError('numeric column contains nonnumeric value')
   elif kinds==['data']:
    require(value.startswith('0x'),'byte value lacks hex prefix')
    raw=bytes.fromhex(value[2:]);require(raw.hex()==value[2:],'noncanonical byte hex')
 if len(rows)==1:require(table['first_time'] is None and table['last_time'] is None,'empty time bounds must be null')
 else:require(table['first_time']==rows[1][1] and table['last_time']==rows[-1][1],'time bounds mismatch')
 for c,n in zip(columns,valid_counts):
  require(c.get('valid_rows')==n and c.get('invalid_rows')==len(rows)-1-n,'validity count mismatch')
  require(bool(c['valid_value_kinds'])==(n>0),'observed kinds/count mismatch')
 return {'status':'pass','rows':len(rows)-1,'columns':len(columns),'source_sha256':receipt['source']['sha256'],'csv_sha256':receipt['csv']['sha256']}

def main():
 if len(sys.argv)!=4:raise ValueError('Usage: verify_export.py SOURCE_MF4 EXPORTED_CSV RECEIPT_JSON')
 source,csv_file,receipt=map(Path,sys.argv[1:]);result=verify(source.read_bytes(),csv_file.read_bytes(),json.loads(receipt.read_text(encoding='utf-8')))
 print(json.dumps(result))
if __name__=='__main__':
 try:main()
 except (ValueError,KeyError,TypeError,OSError,csv.Error) as error:
  print('Export verification failed: '+str(error),file=sys.stderr);sys.exit(1)
