"""Verificador de âncoras `arquivo:linha` dos documentos.

Confere o que uma régua de existência não vê. Quatro classes objetivas:

1. arquivo que não existe;
2. número **fora do arquivo**;
3. faixa **em branco**;
4. **rótulo fora da definição ou do corpo** — quando o próprio texto do link
   é um símbolo (``[`nome`](../src/arquivo.gd#LNNN)``), o alvo tem de cobrir a
   linha em que ele é declarado **ou** cair inteiro dentro do corpo daquela
   declaração. É uma afirmação verificável, não uma opinião: a frase diz o
   nome, o arquivo diz onde o nome vive.

O que continua fora daqui: a prosa livre que cita um número sem nomear símbolo
nenhum — número dentro do arquivo, linha com texto, e a frase podendo afirmar
outra coisa. Essa classe exige abrir o alvo e ler contra a frase, e é por isso
que a saída é uma lista de casos, não um "docs ok".

    python tools/check_doc_anchors.py            # corpus: AGENTS.md, README.md, docs/**
    python tools/check_doc_anchors.py docs/planos
    python tools/check_doc_anchors.py --ref HEAD # os mesmos documentos de uma revisao

Com `--ref` os **documentos** vêm do git daquela revisão e os **alvos** continuam
do disco: é o par antes/depois de uma passada de re-derivação, medido pela mesma
régua, sem depender de memória. Cada corrida imprime o total de ponteiros e de
rótulos conferidos, os casos encontrados e termina com código 1 se houver caso.
"""

import io
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# [rótulo](../src/x.gd#L12-L13)  |  src/x.gd:12-13  |  `:12-13` (herda o último caminho da linha)
LINK = re.compile(r"\]\((?:\.\./)*((?:src|tests|docs)/[\w./-]+\.(?:gd|md))#L(\d+)(?:-L(\d+))?\)")
BARE = re.compile(r"((?:\.\./)*/?(?:src|tests|docs)/[\w./-]+\.(?:gd|md)):(\d+)(?:-(\d+))?")
CONT = re.compile(r"(?<![\w./-]):(\d+)(?:-(\d+))?")

# [`nome`](../src/x.gd#L12)  |  [`nome()`](../src/x.gd#L12-L13)
LABEL = re.compile(r"\[`([A-Za-z_][\w]*)(?:\(\))?`\]\((?:\.\./)*((?:src|tests|docs)/[\w./-]+\.gd)#L(\d+)(?:-L(\d+))?\)")
# declaracoes de topo em GDScript: sem recuo
DEFPAT = re.compile(r"^(\s*)(?:static\s+)?(func|var|const|enum)\s+(_?[A-Za-z_][\w]*)")

cache = {}
defs_cache = {}


def doc_files(prefixes):
    out = []
    for raw in prefixes:
        prefix = raw.replace("\\", "/").rstrip("/")
        full = os.path.join(ROOT, prefix)
        if os.path.isfile(full):
            out.append(prefix)
            continue
        for dirpath, dirnames, filenames in os.walk(full):
            dirnames[:] = [d for d in dirnames if d != "evidence"]
            for fn in sorted(filenames):
                if fn.endswith(".md"):
                    rel = os.path.relpath(os.path.join(dirpath, fn), ROOT)
                    out.append(rel.replace("\\", "/"))
    return sorted(set(out))


def corpus_from_ref(ref):
    """Os .md rastreados daquela revisao (evidence fora); alvos continuam no disco."""
    listing = subprocess.run(["git", "ls-tree", "-r", "--name-only", ref],
                             cwd=ROOT, capture_output=True, text=True,
                             encoding="utf-8").stdout
    out = {}
    for rel in sorted(listing.replace("\\", "/").splitlines()):
        if not rel.endswith(".md"):
            continue
        if rel not in ("AGENTS.md", "README.md") and not rel.startswith("docs/"):
            continue
        if rel.startswith("docs/evidence/"):
            continue
        body = subprocess.run(["git", "show", "%s:%s" % (ref, rel)],
                              cwd=ROOT, capture_output=True, text=True,
                              encoding="utf-8")
        if body.returncode == 0:
            out[rel] = body.stdout
    return out


def read_doc(rel):
    return io.open(os.path.join(ROOT, rel), encoding="utf-8").read()


def lines_of(rel):
    if rel not in cache:
        full = os.path.join(ROOT, rel)
        cache[rel] = io.open(full, encoding="utf-8").read().split("\n") \
            if os.path.exists(full) else None
    return cache[rel]


def defs_of(rel):
    """nome -> lista de (linha de definicao, ultima linha do corpo), so declaracoes de topo."""
    if rel not in defs_cache:
        d = {}
        src = lines_of(rel)
        if src is not None:
            tops = []
            for n, line in enumerate(src, 1):
                m = DEFPAT.match(line)
                if m and m.group(1) == "":
                    tops.append((n, m.group(3)))
            for i, (n, name) in enumerate(tops):
                end = tops[i + 1][0] - 1 if i + 1 < len(tops) else len(src)
                d.setdefault(name, []).append((n, end))
        defs_cache[rel] = d
    return defs_cache[rel]


def label_events(line):
    return [(m.group(1), m.group(2), int(m.group(3)), int(m.group(4) or m.group(3)))
            for m in LABEL.finditer(line)]


def events_of(line):
    """Ponteiros na ordem em que aparecem; `None` no caminho = continuação."""
    events = []
    spans = []
    for m in LINK.finditer(line):
        events.append((m.start(), m.group(1), int(m.group(2)), int(m.group(3) or m.group(2))))
        spans.append((m.start(), m.end()))
    for m in BARE.finditer(line):
        path = m.group(1).split("../")[-1].lstrip("/")
        events.append((m.start(), path, int(m.group(2)), int(m.group(3) or m.group(2))))
        spans.append((m.start(), m.end()))
    for m in CONT.finditer(line):
        # `[`:218-220`](src/...)` é rótulo de link, não continuação: o alvo está no próprio URL
        if line[m.end():m.end() + 2] == "](" or line[m.end():m.end() + 1] == ")":
            continue
        if any(s <= m.start() < e for s, e in spans):
            continue
        events.append((m.start(), None, int(m.group(1)), int(m.group(2) or m.group(1))))
    return sorted(events)


def main(argv):
    argv = argv[1:]
    ref = None
    if "--ref" in argv:
        i = argv.index("--ref")
        ref = argv[i + 1]
        argv = argv[:i] + argv[i + 2:]
    prefixes = argv or ["AGENTS.md", "README.md", "docs"]
    if ref:
        docs = corpus_from_ref(ref)
    else:
        docs = {rel: read_doc(rel) for rel in doc_files(prefixes)}
    checked = 0
    labels = 0
    rows = []
    for rel in sorted(docs):
        for n, line in enumerate(docs[rel].split("\n"), 1):
            last = None
            for (_pos, path, a, b) in events_of(line):
                if path:
                    last = path
                    if not last.startswith(("src/", "tests/", "docs/")):
                        continue
                if last is None:
                    continue
                checked += 1
                if not os.path.exists(os.path.join(ROOT, last)):
                    rows.append("%s:%d  %s  arquivo NAO EXISTE" % (rel, n, last))
                    continue
                src = lines_of(last)
                if a > len(src):
                    rows.append("%s:%d  %s:%d-%d  FORA DO ARQUIVO (tem %d)" % (rel, n, last, a, b, len(src)))
                    continue
                if all(s.strip() == "" for s in src[a - 1:b]):
                    rows.append("%s:%d  %s:%d-%d  BRANCO" % (rel, n, last, a, b))
            for (name, path, a, b) in label_events(line):
                sp = defs_of(path).get(name)
                if not sp:
                    continue
                labels += 1
                if not (any(x <= a and b <= e for x, e in sp)
                        or any(x >= a and x <= b for x, e in sp)):
                    rows.append("%s:%d  %s:%d-%d  ROTULO FORA DO CORPO [%s] em %s"
                                % (rel, n, path, a, b, name,
                                   ",".join("%d-%d" % s for s in sp[:2])))
    print("%s  arquivos: %d  ponteiros conferidos: %d  rotulos conferidos: %d"
          % (("corpus em " + ref) if ref else "corpus na arvore de trabalho",
             len(docs), checked, labels))
    for r in sorted(set(rows)):
        print(r)
    print("casos objetivos: %d" % len(set(rows)))
    return 1 if rows else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
