"""Passo 2 (a) do dossie 22 (S5.1, S12.3, S1.3): gera as bibliotecas de importacao do
export-set MEDIDO, nao da documentacao.

O motivo de existir: em `.tools/llama/runtime/` nao ha nenhuma `.lib` (S12.3), e o
`llama.dll` do build pinado exporta 266 nomes enquanto o `ggml.dll` do mesmo build exporta
16 (S1.3). Um binding escolhido pela documentacao do llama.cpp pode referir um nome que nao
esta naquela DLL — e ai o link falha em runtime com um crash, nao com um vermelho. Entao a
unica fonte de verdade aqui e o `dumpbin /exports` arquivado em
`docs/evidence/oraculo-nativo-22/exports-*.txt`, e o gate e o proprio linker.

O que este script faz, e nada alem disso:

1. le os dumps arquivados (a testemunha com hash no manifesto da pasta);
2. se o runtime existir no disco, re-mede com `dumpbin /exports` e **confere o conjunto de
   nomes** contra o dump arquivado — divergencia e recusa, nao aviso, porque a licenca do
   pin (THIRD_PARTY_LICENSES: b12499) e o que sustenta os numeros do S1.3;
3. escreve um `.def` por DLL com os nomes **C puro** do export-set. O ordinal medido fica no
   dump arquivado, NAO no `.def`: com `nome @37` o `lib /def:` produz import **por ordinal**, o
   `dumpbin /imports` do exe perde o nome e a regua de modulo do `check_imports.py` morre.
   O `--ordinal` escreve a forma com `@n` e so existe para o A/B que mede essa frase (passo 2a);
   o build nao o usa nunca.

Os nomes C++-decorados (26 no `llama.dll`) vao para o `.def` so se o `--decorated` pedir:
o binding nao chama nenhum, e um `.def` menor e um gate mais apertado — referenciar um nome
que nao esta ali e `LNK2019`, e e isso que o controle negativo do `build.bat` prova rodando.

Uso (dentro da casca do vcvars, chamado pelo build.bat):

    python native\\af_mind\\gen_import_libs.py --out native\\af_mind\\bin ^
        [--runtime C:\\Aetherfall\\.tools\\llama\\runtime]

Saida: uma linha `[def]` por DLL e, se `--runtime`, uma linha `[remedio]` por DLL conferida.
Codigo de saida 0 = os `.def` escritos e os conjuntos conferidos; 1 = recusa.
"""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys

EVIDENCE_DIR = os.path.join("docs", "evidence", "oraculo-nativo-22")

# A tabela do dumpbin e `ordinal hint RVA nome`. A coluna de ordinal e decimal e comeca em 1;
# a de HINT E HEX (`A`, `100`, `10F`) -- e foi ai que este parser esteve errado: pedir `(\d+)`
# na hint descarta toda linha cuja hint tem letra, e o `llama.dll` passava a ter 110 nomes em
# vez dos 266 medidos no S1.3. O que tornava o erro invisivel e pior que o erro: o mesmo
# parser le o dump arquivado e a DLL viva, entao os dois conjuntos divergem IGUALMENTE e a
# conferencia "iguais" sai verde. A regua contra isso e a linha `N number of names` que o
# proprio dumpbin imprime no summary -- ela nao depende do meu regex de linha.
ROW_RE = re.compile(r"^\s*(\d+)\s+([0-9A-Fa-f]+)\s+([0-9A-Fa-f]{4,16})\s+(\S+)\s*$")
DUMP_OF_RE = re.compile(r"^Dump of file (.+)$")
NAMES_RE = re.compile(r"^\s*(\d+) number of names\s*$")


def parse_dump(text: str) -> tuple[str, dict[str, int], int]:
    """Devolve (nome do modulo, {símbolo: ordinal}, contagem declarada pelo dumpbin)."""
    module = ""
    declared = -1
    names: dict[str, int] = {}
    for line in text.splitlines():
        m = DUMP_OF_RE.match(line.strip())
        if m and not module:
            module = os.path.basename(m.group(1).strip())
            continue
        m = NAMES_RE.match(line)
        if m:
            declared = int(m.group(1))
            continue
        m = ROW_RE.match(line)
        if m:
            ordinal = int(m.group(1))
            symbol = m.group(4)
            # `dumpbin` tambem imprime linhas de summary/endereco com o mesmo desenho de
            # quatro colunas; o discrimante e o ordinal comecar em 1 e o nome nao ser hex.
            if ordinal >= 1 and not re.fullmatch(r"[0-9A-Fa-f]+", symbol):
                names[symbol] = ordinal
    return module, names, declared


def measure_live(dll_path: str) -> tuple[dict[str, int], int]:
    """Re-mede o export-set de uma DLL real com o dumpbin da casca do vcvars."""
    proc = subprocess.run(
        ["dumpbin", "/exports", dll_path],
        capture_output=True,
        text=True,
        errors="replace",
    )
    if proc.returncode != 0:
        raise SystemExit(f"[recusa] dumpbin saiu com {proc.returncode} em {dll_path}")
    _, names, declared = parse_dump(proc.stdout)
    if not names:
        raise SystemExit(f"[recusa] dumpbin nao devolveu nenhuma linha de export em {dll_path}")
    return names, declared


def write_def(path: str, module: str, names: dict[str, int], decorated: bool,
              dump: str, ordinal: bool) -> int:
    puros = {k: v for k, v in names.items() if "@@" not in k}
    chosen = names if decorated else puros
    with open(path, "w", encoding="ascii", newline="\r\n") as fh:
        # O cabecalho e um comentario de `.def` (o `lib` ignora a linha com `;`), e a razao dele
        # e medida, nao de gosto: escrevendo `nome @37` o `lib /def:` produz uma biblioteca cuja
        # importacao e POR ORDINAL -- o `dumpbin /imports` do exe ligado passa a imprimir
        # `Ordinal 167` sem nome nenhum, e a regua de que "este nome vem desta DLL" deixa de
        # existir. Sem o `@`, a tabela sai com `hint nome` e o ordinal medido continua vivo no
        # dump arquivado, que e a testemunha dele desde o S1.3.
        # O `--ordinal` escreve a forma ERRADA de proposito, para o A/B de
        # `docs/evidence/oraculo-nativo-22/passo2a_ordinal_ab.bat` medir a frase acima em vez
        # de deixa-la como comentario. Nao e opcao do build: o build nunca a passa.
        fh.write(f"; gerado de {dump} (dumpbin /exports do pin b12499)\n")
        fh.write("; nomes COM ordinal (`@n`): import por ordinal, a tabela de imports perde o nome\n"
                 if ordinal else
                 "; nomes SEM ordinal: com `@n` o import sai por ordinal e a tabela perde o nome\n")
        fh.write(f"LIBRARY {module}\n")
        fh.write("EXPORTS\n")
        for symbol in sorted(chosen):
            fh.write(f"    {symbol} @{chosen[symbol]}\n" if ordinal else f"    {symbol}\n")
    return len(chosen)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True, help="pasta onde escrever os .def (bin/)")
    ap.add_argument("--runtime", default="", help="pasta do runtime, para conferir; opcional")
    ap.add_argument("--decorated", action="store_true", help="incluir os nomes C++-decorados")
    ap.add_argument("--ordinal", action="store_true",
                    help="A/B do passo 2a: escrever `nome @n`, a forma que apaga o nome da tabela")
    ap.add_argument("--evidence", default=EVIDENCE_DIR)
    args = ap.parse_args()

    dumps = sorted(
        f for f in os.listdir(args.evidence)
        if f.startswith("exports-") and f.endswith(".txt")
    )
    if not dumps:
        print(f"[recusa] nenhum exports-*.txt em {args.evidence}", flush=True)
        return 1

    os.makedirs(args.out, exist_ok=True)
    recusado = False
    for dump_name in dumps:
        dump_path = os.path.join(args.evidence, dump_name)
        with open(dump_path, "r", encoding="utf-8", errors="replace") as fh:
            module, archived, declarado_arq = parse_dump(fh.read())
        if not module or not archived:
            print(f"[recusa] {dump_name}: modulo={module or '<vazio>'} nomes={len(archived)}", flush=True)
            recusado = True
            continue
        # A regua do instrumento, nao do dado: se o meu parse nao devolve a contagem que o
        # proprio dumpbin declarou no summary, o culpado e o ROW_RE -- e um .def silencio
        # mente para o linker com LNK2019 em vez de dizer que a leitura esta torta.
        if declarado_arq != len(archived):
            print(
                f"[recusa] {dump_name}: parse devolve {len(archived)} nomes, "
                f"o dumpbin declarou {declarado_arq} -- parser errado, nao pin diferente",
                flush=True,
            )
            recusado = True
            continue

        # --- re-medida: o dump arquivado e a testemunha, a DLL no disco e a verdade -------
        ao_vivo = -1
        vivo_declado = -1
        if args.runtime:
            dll_path = os.path.join(args.runtime, module)
            if os.path.isfile(dll_path):
                vivos, vivo_declado = measure_live(dll_path)
                ao_vivo = len(vivos)
                if vivo_declado != ao_vivo:
                    print(
                        f"[recusa] {module} vivo: parse devolve {ao_vivo}, dumpbin declara "
                        f"{vivo_declado}",
                        flush=True,
                    )
                    recusado = True
                    continue
                faltando = sorted(set(archived) - set(vivos))
                sobrando = sorted(set(vivos) - set(archived))
                if faltando or sobrando:
                    print(
                        f"[remedio] {module}: DIVERGE do dump arquivado "
                        f"(arquivado={len(archived)} vivo={len(vivos)} "
                        f"so_no_dump={len(faltando)} so_no_disco={len(sobrando)})",
                        flush=True,
                    )
                    for s in faltando[:10]:
                        print(f"[remedio]   so_no_dump {s}", flush=True)
                    for s in sobrando[:10]:
                        print(f"[remedio]   so_no_disco {s}", flush=True)
                    recusado = True
                    continue
                print(f"[remedio] {module}: iguais ({len(vivos)} nomes)", flush=True)
            else:
                print(f"[remedio] {module}: {dll_path} nao existe -- uso so o dump arquivado", flush=True)

        def_path = os.path.join(args.out, module.replace(".dll", "") + ".def")
        escritos = write_def(def_path, module, archived, args.decorated,
                             f"{args.evidence}/{dump_name}", args.ordinal)
        puros = len([k for k in archived if "@@" not in k])
        print(
            f"[def] {module}: arquivo={os.path.basename(def_path)} entradas={escritos} "
            f"export_total={len(archived)} c_puro={puros} cpp_decorado={len(archived) - puros} "
            f"remedio={'sim' if ao_vivo >= 0 else 'nao'}",
            flush=True,
        )

    if recusado:
        print("[recusa] o export-set do disco nao e o do dump arquivado: o pin b12499 mudou", flush=True)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
