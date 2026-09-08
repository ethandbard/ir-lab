"""Local grader harness for IR Lab lessons.

For every exercise in a .qmd: run its setup chunk(s), then the solution
from the .solution block (its last expression becomes .result in R or
result in Python), then the #| check: true chunk, and print the feedback.
R exercises run through Rscript in the project directory with the page's
`webr: packages:` attached first, as the browser does before any cell runs;
Python ones run in this process. Usage: python grade.py lesson.qmd [...]
"""
import ast
import io
import re
import subprocess
import sys
import textwrap
import contextlib

RSCRIPT = r"C:\Program Files\R\R-4.6.0\bin\Rscript.exe"


def parse_opts(body):
    opts, code, cur = {}, [], None
    for ln in body.split("\n"):
        m = re.match(r"#\|\s?(.*)$", ln)
        if m:
            t = m.group(1)
            if t.strip().startswith("-") and cur is not None:
                if not isinstance(opts[cur], list):
                    opts[cur] = []
                opts[cur].append(t.strip()[1:].strip())
            else:
                mm = re.match(r"([\w-]+):\s*(.*)$", t)
                if mm:
                    cur = mm.group(1)
                    opts[cur] = mm.group(2).strip()
        else:
            code.append(ln)
    return opts, "\n".join(code)


def r_packages(qmd):
    """Packages under webr: packages: in the front matter."""
    m = re.match(r"---\n(.*?)\n---", qmd, re.S)
    if not m:
        return []
    block = re.search(r"^webr:\n((?:[ \t]+\S.*\n?)+)", m.group(1) + "\n", re.M)
    if not block:
        return []
    pk = re.search(r"^[ \t]+packages:\n((?:[ \t]+-[ \t]*\S+\n?)+)", block.group(1), re.M)
    return re.findall(r"-[ \t]*(\S+)", pk.group(1)) if pk else []


def collect(qmd):
    setups, checks, sols = {}, {}, {}
    for lang, body in re.findall(r"```\{(webr|pyodide)\}\n(.*?)\n```", qmd, re.S):
        opts, code = parse_opts(body)
        ex = opts.get("exercise")
        if ex is None:
            continue
        ids = ex if isinstance(ex, list) else [ex]
        if opts.get("setup") == "true":
            for i in ids:
                setups.setdefault((lang, i), []).append(code)
        elif opts.get("check") == "true":
            for i in ids:
                checks[(lang, i)] = code
    for m in re.finditer(r':::\s*\{\.solution exercise="([^"]+)"\}\n(.*?)\n:::\n:::', qmd, re.S):
        mm = re.search(r"```(r|python)\n(.*?)\n```", m.group(2), re.S)
        if mm:
            sols[m.group(1)] = mm.group(2)
    return setups, checks, sols


def run_r(setup, solution, check, packages=()):
    attach = "suppressPackageStartupMessages({" + "".join(f"library({p});" for p in packages) + "})\n"
    script = attach + "\n".join(setup) + "\n.result <- {\n" + solution + "\n}\n.__fb <- {\n" + check + "\n}\ncat(sprintf('correct=%s | %s\\n', .__fb$correct, .__fb$message))\n"
    out = subprocess.run([RSCRIPT, "-e", "source(textConnection(readLines('stdin')))"], input=script, capture_output=True, text=True)
    text = (out.stdout + out.stderr).strip().split("\n")
    lines = [l for l in text if l.startswith("correct=")]
    return lines[-1] if lines else "ERROR: " + "\n".join(text[-8:])


def run_py(setup, solution, check):
    ns = {}
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        for s in setup:
            exec(s, ns)
        tree = ast.parse(solution)
        if tree.body and isinstance(tree.body[-1], ast.Expr):
            head = ast.Module(body=tree.body[:-1], type_ignores=[])
            exec(compile(head, "<solution>", "exec"), ns)
            ns["result"] = eval(compile(ast.Expression(tree.body[-1].value), "<solution>", "eval"), ns)
        else:
            exec(solution, ns)
            ns["result"] = None
        exec(check, ns)
    fb = ns.get("feedback")
    return f"correct={fb['correct']} | {fb['message']}" if fb else "ERROR: no feedback"


def main(paths):
  for path in paths:
    qmd = open(path, encoding="utf-8").read()
    packages = r_packages(qmd)
    setups, checks, sols = collect(qmd)
    print(f"=== {path}: {len(checks)} checks, {len(sols)} solutions")
    for (lang, i), check in checks.items():
        sol = sols.get(i)
        if sol is None:
            print(f"  {i}: NO SOLUTION BLOCK")
            continue
        setup = setups.get((lang, i), [])
        try:
            res = run_r(setup, sol, check, packages) if lang == "webr" else run_py(setup, sol, check)
        except Exception as e:  # noqa: BLE001
            res = f"ERROR: {e!r}"
        print(f"  {i} [{lang}]: {res}")


if __name__ == "__main__":
    main(sys.argv[1:])
