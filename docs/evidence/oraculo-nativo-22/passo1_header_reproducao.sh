#!/bin/sh
# Passo 1 (a) — reproducao do cabecalho de interface 4.7.2 a partir das duas entradas baixadas.
# Rodar em Git Bash:  sh docs/evidence/oraculo-nativo-22/passo1_header_reproducao.sh
# Nao toca a arvore do projeto: work em /tmp, e compara com o arquivo arquivado aqui do lado.
set -u
RAIZ=$(git rev-parse --show-toplevel)
ARQ="$RAIZ/docs/evidence/oraculo-nativo-22/gdextension_interface_472.h"
IN="$RAIZ/.tools/gdextension-interface-src"

echo "== Passo 1 (a): reproducao do header, $(date -Is), base $(git rev-parse --short HEAD), branch $(git branch --show-current) =="
echo

if [ ! -d "$IN" ]; then
  echo "[entradas] ausentes — o script para aqui por design."
  echo "  O que ele espera em $IN (fora do git, sao artefatos de terceiro baixados):"
  echo "    gdextension_interface.json   328021 B  sha256 7d8c0a039d9743eb8ebf88681ae0c641d8d3aa5ffca11081745a84da803e09a1"
  echo "    make_interface_header.py      12015 B  sha256 a4ed7de907bd4e692faa76ac4232a8461b44256d961c734bb378d0566236fae2"
  echo "  Ambos da tag 4.7.2-stable, diretorio core/extension/ do repositorio do Godot."
  echo "  exit=2 (sem entradas nao ha reproducao; a de baixo roda quando eles estiverem no lugar)"
  exit 2
fi

W=$(mktemp -d)
cp "$IN/gdextension_interface.json" "$IN/make_interface_header.py" "$W"/
cat > "$W/methods.py" <<'PY'
from contextlib import contextmanager
def get_buffer(filename):
    with open(filename, 'rb') as f:
        return f.read()
@contextmanager
def generated_wrapper(path):
    f = open(path, 'w', encoding='utf-8')
    try:
        yield f
    finally:
        f.close()
PY
cat > "$W/gen.py" <<'PY'
import make_interface_header as m
m.run(["out.h"], ["gdextension_interface.json"], None)
print("GERADO")
PY

echo "[entrantes conferidos no work]"
( cd "$W" && sha256sum gdextension_interface.json make_interface_header.py | sed 's/^/  /' )

echo "[gerar]"
( cd "$W" && python gen.py ); echo "  exit=$?"

echo "[comparar com o arquivado]"
echo "  gerado bytes=$(wc -c < "$W/out.h")  sha256=$(sha256sum "$W/out.h" | cut -d' ' -f1)"
echo "  arquivado bytes=$(wc -c < "$ARQ")  sha256=$(sha256sum "$ARQ" | cut -d' ' -f1)"
cmp "$W/out.h" "$ARQ"; echo "  cmp exit=$?  (0 = byte a byte identico)"
rm -rf "$W"

echo
echo "[fim]"
