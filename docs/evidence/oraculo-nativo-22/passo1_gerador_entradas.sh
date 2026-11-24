#!/bin/sh
# Passo 1 (a) — leitura das ENTRADAS do gerador: o que ha no JSON de interface e o que o gerador faz
# com cada uma delas. Rodar em Git Bash, na raiz:
#   sh docs/evidence/oraculo-nativo-22/passo1_gerador_entradas.sh
# Nao escreve nada na arvore do projeto.
set -u
cd "$(git rev-parse --show-toplevel)" || exit 1
SRC=.tools/gdextension-interface-src

echo "== Passo 1 (a): entradas do gerador, $(date -Is), base $(git rev-parse --short HEAD), branch $(git branch --show-current) =="
echo

echo "[os dois arquivos, como chegaram]"
for f in gdextension_interface.json make_interface_header.py; do
  echo "  $f bytes=$(wc -c < "$SRC/$f")  linhas=$(wc -l < "$SRC/$f")  sha256=$(sha256sum "$SRC/$f" | cut -d' ' -f1)"
done

echo
echo "[o JSON, por dentro]"
python -c "
import json
d = json.loads(open('.tools/gdextension-interface-src/gdextension_interface.json','rb').read().decode('utf-8'))
print('  chaves de topo (ordem):', list(d.keys()))
print('  format_version =', d.get('format_version'))
print('  api_version presente?', 'api_version' in d)
print('  types = %d entradas, interface = %d funcoes' % (len(d['types']), len(d['interface'])))
enum = d['types'][0]
print('  enum[0] = %s com %d valores (ultimo: %s = %d)' % (enum['name'], len(enum['values']), enum['values'][-1]['name'], enum['values'][-1]['value']))
c = d['_copyright']
print('  _copyright = %d linhas' % len(c))
txt = ' '.join(c)
for tok in ['Copyright', 'Permission is hereby granted', 'WITHOUT WARRANTY', 'MIT', 'AUTHORS']:
    print('    contem %r? %s' % (tok, tok in txt))
"
echo "  exit=$?"

echo
echo "[o gerador: existe CLI?]"
grep -c '__main__' "$SRC/make_interface_header.py" | sed 's/^/  ocorrencias_de___main___=/'
grep -c 'argparse\|ArgumentParser\|add_argument' "$SRC/make_interface_header.py" | sed 's/^/  ocorrencias_de_argparse=/'
grep -c 'sys.argv' "$SRC/make_interface_header.py" | sed 's/^/  ocorrencias_de_sys_argv=/'
grep -n '^def run' "$SRC/make_interface_header.py" | sed 's/^/  /'
grep -n 'generated_wrapper\|_copyright' "$SRC/make_interface_header.py" | sed 's/^/  /'

echo
echo "[o shim minimo que o invocou — as duas funcoes que o SCons fornece]"
cat > /tmp/af_shim_$$.py <<'PY'
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
echo "  bytes=$(wc -c < /tmp/af_shim_$$.py)  linhas=$(wc -l < /tmp/af_shim_$$.py)  sha256=$(sha256sum /tmp/af_shim_$$.py | cut -d' ' -f1)"
rm -f /tmp/af_shim_$$.py

echo
echo "[o mesmo bloco _copyright, aplicado: quantas linhas de licenca saem no header gerado]"
python -c "
import json
d = json.loads(open('.tools/gdextension-interface-src/gdextension_interface.json','rb').read().decode('utf-8'))
c = '\n'.join(d['_copyright'])
h = open('docs/evidence/oraculo-nativo-22/gdextension_interface_472.h','rb').read().decode('utf-8')
print('  linhas do bloco no JSON: %d' % len(d['_copyright']))
for tok in ['GODOT ENGINE', 'Permission is hereby granted', 'MIT', 'AUTHORS']:
    print('  header gerado contem %r? %s' % (tok, tok in h))
"
echo "  exit=$?"

echo
echo "[fim]"
