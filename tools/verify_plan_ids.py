import os
import re
import sys
from pathlib import Path

# Mesma razao da outra regua: a raiz e o diretorio que contem tools/.
ROOT = Path(os.environ.get("AETHER_ROOT", Path(__file__).resolve().parent.parent))

# corpus: todo codigo-fonte, testes e a extensao nativa, de uma vez. O native/
# entra porque desde o dossie 22 as paginas citam identificadores de .cpp/.h e a
# regua devolvia como "ausente" o que existia (furo #39).
corpus = []
globs = ["src/**/*.gd", "tests/**/*.gd", "native/**/*.cpp", "native/**/*.h"]
for g in globs:
    corpus.extend(p.read_text(encoding="utf-8", errors="ignore") for p in ROOT.glob(g))
CORPUS = "\n".join(corpus)

idpat = re.compile(r"`([A-Za-z_][A-Za-z0-9_]{2,})`")
known_words = set("""
func var const return if else elif for while in match class_name extends signal enum
true false null self super await async assert break continue pass preload
""".split())

for arg in sys.argv[1:]:
    doc = (ROOT / arg).read_text(encoding="utf-8")
    ids = sorted(set(idpat.findall(doc)) - known_words)
    missing = [i for i in ids if i not in CORPUS]
    print("== " + arg + " -- identificadores citados em backticks: %d" % len(ids))
    if missing:
        print("   AUSENTES em src/, tests/ e native/: " + ", ".join(missing))
    else:
        print("   todos existem em src/, tests/ ou native/")
