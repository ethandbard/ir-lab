"""Package source definitions and required CSVs for the lesson download.

Runs as the Quarto pre-render hook, so it also runs for every page that
`quarto preview` renders on demand. The zip lives under `data/`, a site
resource, and rewriting a resource during preview makes the preview server
broadcast a reload that cancels the navigation in progress. So: only rebuild
when an input is newer than the existing zip, and write atomically.
"""
import os
import sys
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

root = Path(__file__).resolve().parents[2]
out = root / 'data/ir-lab-powerbi.zip'
files = [root / 'data/institutions.csv', root / 'data/variables.csv', root / 'powerbi-embed.json', root / 'powerbi-embed.js']
files += [p for p in (root / 'powerbi').rglob('*')
          if p.is_file()
          and not any(x in p.parts for x in ['.pbi', '__pycache__'])
          and p.suffix not in ['.pbix', '.pyc']]
files = sorted(set(files))


def zip_ok(path):
    try:
        with ZipFile(path) as z:
            return z.testzip() is None and 'powerbi/IR Lab.pbip' in z.namelist()
    except Exception:
        return False


if out.exists() and zip_ok(out):
    newest = max(p.stat().st_mtime for p in files)
    if out.stat().st_mtime >= newest:
        print(out, out.stat().st_size, 'bytes (up to date)')
        sys.exit(0)

tmp = out.with_name(out.name + '.tmp')
with ZipFile(tmp, 'w', ZIP_DEFLATED) as z:
    for p in files:
        z.write(p, p.relative_to(root))
assert zip_ok(tmp), 'packaged zip failed verification'
os.replace(tmp, out)
print(out, out.stat().st_size, 'bytes (rebuilt)')
