"""One-time repair of the existing IR Lab project without replacing visual layouts."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def literal(value):
    return {'expr': {'Literal': {'Value': value}}}

def style_visual(document):
    visual = document['visual']
    objects = visual.setdefault('objects', {})
    if visual['visualType'] == 'card':
        objects['categoryLabels'] = [{'properties': {'show': literal('false')}}]
        objects['labels'] = [{'properties': {'labelDisplayUnits': literal('0D'), 'fontSize': literal('28D')}}]
    if visual['visualType'] == 'slicer':
        objects['header'] = [{'properties': {'show': literal('false')}}]
        if document['name'] == 'cohort':
            objects['data'] = [{'properties': {'mode': literal("'Between'")}}]
    return document

def clean(text):
    for character in '\u2013\u00b7\u2022\u2192\u2265':
        text = text.replace(character.encode('utf-8').decode('cp1252'), character)
    return text

changed = []
for path in ROOT.rglob('*'):
    if not path.is_file() or '.pbi' in path.parts or path.suffix not in {'.json', '.tmdl', '.py', '.md'}:
        continue
    old = path.read_text(encoding='utf-8-sig')
    new = clean(old)
    if path.suffix == '.tmdl':
        new = new.replace('\t\t\tformatString:', '\t\tformatString:')
    if path.name == 'build_project.py':
        new = new.replace("['\\t\\t'+v for v in m['expression'].splitlines()]", "['\\t\\t\\t'+v for v in m['expression'].splitlines()]")
    if path.name == 'visual.json':
        document = style_visual(json.loads(new))
        container = document.get('visual', {}).get('visualContainerObjects', {})
        for title in container.get('title', []):
            props = title['properties']
            props['fontColor'] = {'solid': {'color': {'expr': {'Literal': {'Value': "'#14213d'"}}}}}
            props['fontSize'] = {'expr': {'Literal': {'Value': '20D' if document['name'] == 'heading' else '12D'}}}
        new = json.dumps(document, ensure_ascii=False, indent=2) + '\n'
    if path.name == 'report.json':
        document = json.loads(new)
        document['themeCollection']['customTheme']['name'] = 'IRLab.json'
        for package in document['resourcePackages']:
            for item in package['items']:
                if item['type'] == 'CustomTheme':
                    item['name'] = item['path'] = 'IRLab.json'
        new = json.dumps(document, ensure_ascii=False, indent=2) + '\n'
    if new != old:
        path.write_text(new, encoding='utf-8')
        changed.append(str(path.relative_to(ROOT)))
print(json.dumps({'repaired_files': changed}, indent=2))
