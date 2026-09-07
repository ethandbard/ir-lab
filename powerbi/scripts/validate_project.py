"""Validate all PBIP/PBIR JSON against a downloaded Microsoft schema registry.
Usage: python validate_project.py /path/to/registry.json [--deps /path/to/jsonschema]
"""
import argparse, json, sys, warnings
from pathlib import Path
parser=argparse.ArgumentParser()
parser.add_argument('registry', type=Path)
parser.add_argument('--deps', type=Path)
args=parser.parse_args()
if args.deps: sys.path.insert(0,str(args.deps.resolve()))
warnings.filterwarnings('ignore', category=DeprecationWarning)
from jsonschema import Draft7Validator
from referencing import Registry, Resource
root=Path(__file__).resolve().parents[1]
schemas=json.loads(args.registry.read_text(encoding='utf-8'))
registry=Registry().with_resources((u,Resource.from_contents(s)) for u,s in schemas.items())
errors=[]; count=0
for p in root.rglob('*'):
    if not p.is_file() or p.suffix not in ['.json','.pbip','.pbir','.pbism']: continue
    d=json.loads(p.read_text(encoding='utf-8'))
    if '$schema' not in d: continue
    u=d['$schema']; sc=schemas[u]
    for e in Draft7Validator(sc,registry=registry).iter_errors(d):
        errors.append(f'{p.relative_to(root)}: {list(e.path)}: {e.message}')
    count+=1
model=json.loads((root/'validation/model-definition.json').read_text(encoding='utf-8'))
tables={t['name']:t for t in model['model']['tables']}
def check_fields(o):
    if isinstance(o,dict):
        for typ,key in [('Column','columns'),('Measure','measures')]:
            if typ in o:
                f=o[typ]; entity=f.get('Expression',{}).get('SourceRef',{}).get('Entity')
                if entity:
                    assert entity in tables, entity
                    assert f['Property'] in {x['name'] for x in tables[entity][key]}, f
        for v in o.values(): check_fields(v)
    elif isinstance(o,list):
        for v in o: check_fields(v)
visuals=list((root/'IR Lab.Report').rglob('visual.json'))
for p in visuals:
    d=json.loads(p.read_text(encoding='utf-8')); check_fields(d)
    pos=d['position']; assert pos['x']>=0 and pos['y']>=0 and pos['x']+pos['width']<=1280 and pos['y']+pos['height']<=900
config=json.loads((root.parent/'powerbi-embed.json').read_text())
pages=json.loads((root/'IR Lab.Report/definition/pages/pages.json').read_text())['pageOrder']
assert set(config['pages'].values())==set(pages)
result={'schema_documents_validated':count,'visuals':len(visuals),'errors':errors,'field_references_checked':True,'page_mappings_checked':True,'desktop_render_verified':False}
(root/'validation/report-checks.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
sys.exit(bool(errors))
