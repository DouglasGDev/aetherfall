#!/bin/sh
# Passo 1 (a) — leitura da FONTE do cabeçalho de interface GDExtension e da ABI que o Passo 1 assina.
# Rodar em Git Bash, na raiz do projeto:  sh docs/evidence/oraculo-nativo-22/passo1_header_fonte_abi.sh
# Saída literal; cada bloco imprime o código de saída do comando que ele mostra.
set -u
cd "$(git rev-parse --show-toplevel)" || exit 1
H=docs/evidence/oraculo-nativo-22/gdextension_interface_472.h
H44=.tools/godot-cpp-godot-4.4.1-stable/gdextension/gdextension_interface.h

echo "== Passo 1 (a): fonte do cabecalho + ABI, $(date -Is), base $(git rev-parse --short HEAD), branch $(git branch --show-current) =="
echo

echo "[onde esta o gerador do cabecalho]"
find . -path ./.git -prune -o \( -name 'gdextension_interface.json' -o -name 'make_interface_header.py' \) -print
echo "  exit=$?  (sem saida acima = nem o JSON nem o gerador estao nesta arvore)"

echo "[cabecalhos de interface em qualquer caminho local]"
find . -path ./.git -prune -o -iname 'gdextension_interface*' -print
echo "  exit=$?"

echo
echo "[o unico cabecalho local: 4.4.1, na arvore do godot-cpp]"
echo "  bytes=$(wc -c < "$H44")  linhas=$(grep -c '' "$H44")"
echo "  sha256=$(sha256sum "$H44" | cut -d' ' -f1)"
echo "  CreationInfomax=$(grep -o 'GDExtensionClassCreationInfo[0-9]*' "$H44" | sort -u | tail -1)"
echo "  CreateInstancimax=$(grep -o 'GDExtensionClassCreateInstance[0-9]*' "$H44" | sort -u | tail -1)"
echo "  ocorrencias_RegisterExtensionClass6=$(grep -c 'RegisterExtensionClass6' "$H44")"

echo
echo "[o cabecalho de 4.7.2, fruto do gerador do proprio Godot]"
echo "  bytes_cru=$(wc -c < "$H44" > /dev/null; wc -c < "$H")"
echo "  sha256_cru=$(sha256sum "$H" | cut -d' ' -f1)"
tr -d '\r' < "$H" > /tmp/af_h_lf.h
echo "  bytes_forma_lf=$(wc -c < /tmp/af_h_lf.h)"
echo "  sha256_forma_lf=$(sha256sum /tmp/af_h_lf.h | cut -d' ' -f1)"
python -c "
b=open('$H','rb').read()
linhas=b.split(b'\n')
print('  linhas_totais=%d' % (len(linhas)-1))
print('  CR=%d  LF=%d' % (b.count(b'\r'), b.count(b'\n')))
print('  linhas_terminadas_CRLF=%d' % sum(1 for l in linhas[:-1] if l.endswith(b'\r')))
print('  linhas_sem_CR=%d' % sum(1 for l in linhas[:-1] if not l.endswith(b'\r')))
print('  diferenca_bytes=%d (= linhas x 1 CR)' % (len(b) - len(b.replace(b'\r', b''))))
"
echo "  typedefs_de_interface_unicos=$(grep -o 'GDExtensionInterface[A-Za-z0-9_]*' "$H" | sort -u | wc -l)"
echo "  ocorrencias_de_GDExtensionInterface=$(grep -c 'GDExtensionInterface' "$H")"
echo "  macro_de_API_VERSION=$(grep -c 'API_VERSION' "$H")"
echo "  linhas_com_a_palavra_license=$(grep -ci 'licen' "$H")"
grep -in 'licen' "$H" | sed 's/^/    /'

echo
echo "[.gitattributes: o que o git faz com cada caminho]"
for f in "$H" native/af_mind/include/gdextension_interface.h native/af_mind/build.bat; do
  echo "  $f"
  git check-attr text eol -- "$f" | sed 's/^/    /'
done

echo
echo "[ABI que o Passo 1 assina, linha a linha do cabecalho de 4.7.2]"
for L in 118 119 212 216 220 221 222 223 224 225 226 366 367 368 369 370 371 372 373 374 375 376 377 378 379 380 381 382 384 386 387 389 397 399 401 402 716 2954; do
  printf '  :%d %s\n' "$L" "$(sed -n "${L}p" "$H" | tr -d '\r')"
done
echo "  CreationInfo7_existe=$(grep -c 'GDExtensionClassCreationInfo7' "$H")"
echo "  InterfaceObjectNotification_existe=$(grep -c 'GDExtensionInterfaceObjectNotification' "$H")"
echo "  ObjectNotification_no_arquivo=$(grep -c 'ObjectNotification' "$H")"
echo "  CreateInstance3_nao_deprecado=$(sed -n '220p' "$H" | grep -c 'Deprecated')"

echo
echo "[o binario da engine: tokens de registro de extensao]"
python -c "
import os
for exe in ['.tools/Godot_v4.7.2-stable_win64.exe', '.tools/Godot_v4.7.2-stable_win64_console.exe']:
    b=open(exe,'rb').read()
    print('  %s bytes=%d sha256=%s' % (os.path.basename(exe), len(b), __import__('hashlib').sha256(b).hexdigest()))
    for tok in [b'classdb_register_extension_class6', b'extension_list.cfg', b'gdextension_interface.json']:
        print('    %s -> %d ocorrencias' % (tok.decode(), b.count(tok)))
"

echo
echo "[fim]"
