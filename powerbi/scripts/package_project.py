"""Package source definitions and required CSVs for the lesson download."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
root=Path(__file__).resolve().parents[2]
out=root/'data/ir-lab-powerbi.zip'
files=[root/'data/institutions.csv',root/'data/variables.csv',root/'powerbi-embed.json',root/'powerbi-embed.js']
files += [p for p in (root/'powerbi').rglob('*') if p.is_file() and not any(x in p.parts for x in ['.pbi','__pycache__']) and p.suffix not in ['.pbix','.pyc']]
with ZipFile(out,'w',ZIP_DEFLATED) as z:
    for p in sorted(files): z.write(p,p.relative_to(root))
with ZipFile(out) as z:
    assert z.testzip() is None
    assert 'powerbi/IR Lab.pbip' in z.namelist()
print(out, out.stat().st_size, 'bytes')
