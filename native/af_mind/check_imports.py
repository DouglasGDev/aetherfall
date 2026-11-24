"""Passo 2 (a) do dossie 22 (S1.3, S5.1): a regua de que cada simbolo referenciado e importado
do modulo onde ele realmente existe.

O motivo de esta regua existir e um defeito que a Fase 0 ja pagou com corrida perdida: a segunda
sonda imprimiu "0 backends" porque resolveu `ggml_backend_reg_name` pelo modulo errado — o
`GetProcAddress` devolveu nulo em silencio e nenhum link reclamou (S1.3 / comentario de topo de
`af_native_probe3.cpp`). Com import libs, o linker só deixa passar nome que exista num `.def`;
ele NAO sabe em qual dos quatro a funcao mora. Esta regua fecha essa metade: a tabela de imports
do exe construido e comparada com o dono medido no export-set.

De onde vem cada lista, e por que nenhuma e escrita aqui:

 * os NOMES REFERENCIADOS saem das proprias fontes passadas em `--gate` (uma ou mais), das
   linhas `AF_SLOT(nome)` (o gate do Passo 2 (a), que imprime os enderecos ao rodar),
   `AF_REF(nome)` (o corpo do pack do Passo 2 (b), cujo `af_pack_slots` mistura os enderecos
   num checksum) e `AF_PROMPT_REF(nome)` (o corpo da fila do Passo 3, com a mesma mistura no
   `af_prompt_slots`). Mesma regua para os tres: copia nenhuma; se a fonte referencia, esta
   aqui. Multi-fonte porque o dll linka DOIS corpos (pack e prompt) contra a MESMA tabela --
   ler so um deixaria metade dos nomes fora da regua exatamente como o linker nao sabe em
   qual `.def` o nome mora.
 * o DONO de cada nome sai dos `.def` gerados do dumpbin arquivado (`gen_import_libs.py`), e um
   nome referenciado que apareca em dois `.def` e recusa: o linker pegaria o primeiro da linha e
   a tabela mentiria sobre quem exporta.
 * o que FOI IMPORTADO sai de `dumpbin /imports` do exe. A saida e lida pela FORMA das linhas
   (modulo a quatro espacos, `hint nome` mais indentedo) e nao por rotulo em ingles — hint e HEX,
   e e exatamente a coluna que quebrou o parser de exports em S12.4.

Os quatro nomes do controle negativo sao conferidos na tabela: nenhum pode aparecer importado.

Uso (dentro da casca do vcvars, chamado pelo build.bat):

    python native\\af_mind\\check_imports.py --gate native\\af_mind\\src\\symbol_gate.cpp ^
        --absent native\\af_mind\\src\\symbol_gate_absent.cpp ^
        --defs native\\af_mind\\bin --imports native\\af_mind\\bin\\gate-imports.txt

    python native\\af_mind\\check_imports.py --gate native\\af_mind\\src\\mind_pack.cpp ^
        --absent native\\af_mind\\src\\symbol_gate_absent.cpp ^
        --defs native\\af_mind\\bin --imports native\\af_mind\\bin\\af_mind-imports.txt

    python native\\af_mind\\check_imports.py --gate native\\af_mind\\src\\mind_pack.cpp ^
        --gate native\\af_mind\\src\\mind_prompt.cpp ^
        --absent native\\af_mind\\src\\symbol_gate_absent.cpp ^
        --defs native\\af_mind\\bin --imports native\\af_mind\\bin\\af_mind-imports.txt

A segunda corrida e a do Passo 2 (b): a fonte agora e o corpo do pack e a tabela e a do
`af_mind.dll` (que so toca o runtime por delay-load), porque e ESSE binario que o Godot carrega --
um gate verde no exe e um `.dll` sem regua seria a mesma mentira de sempre, so que com outra voz.
A terceira e a do Passo 3 (S5.3): o dll linka TAMBEM o corpo da fila (`mind_prompt.cpp`), e a
regua passa a ler os DOIS corpos de uma vez -- 15 nomes de decode que sem isso ficariam fora da
comparacao entre o que a fonte referencia e o que o binario importa.

Saida: linhas `[referencia]`, `[dono]`, `[import]` e uma linha de veredito. 0 = confere; 1 =
recusa com `[recusa]` impresso.
"""

from __future__ import annotations

import argparse
import glob
import os
import re
import sys

SLOT_RE = re.compile(r"^\s*AF_(?:SLOT|PROMPT_REF|REF)\((\w+)\)\s*;\s*$")
DATA_RE = re.compile(r'^extern void \* (\w+);\s*$')
# O `.def` do Passo 2 (a) traz nomes SEM ordinal (ver gen_import_libs.py); o ` @n` continua
# aceito aqui para que a regua nao dependa de qual das duas formas o .def nasceu.
DEF_ROW_RE = re.compile(r"^    (\w+)(?: @\d+)?\s*$")
DEF_LIB_RE = re.compile(r"^LIBRARY (\S+)\s*$")
# dumpbin /imports: o modulo vem com quatro espacos e, no delay-load, com uma linha de
# "Characteristics" e as tabelas de endereco logo abaixo. Duas formas de linha de nome, ambas
# medidas no binario desta perna (as colunas sao ALINHADAS, entao entre os tokens pode haver
# um ou varios espacos -- foi por exigir um espaco so que a primeira regua leu zero nomes):
#   import comum:  "                         239 GetCurrentProcessId"
#   delay-load:    "       0000000140001B7F    8C llama_print_system_info"
# O que discrimina NOME de ROTULO de tabela nao e uma lista de palavras (escrever rotulo em
# ingles e o que ja quebrou parser nesta casa, com o Windows pt-BR): e que o token colado antes
# do nome e o HINT, hex de no maximo quatro digitos. "00000001 Characteristics" tem oito e
# "0000000140025D68 Address of HMODULE" tem dezesseis -- nenhum dos dois passa.
MOD_RE = re.compile(r"^\s{4}(\S+\.dll)\b(.*)$", re.IGNORECASE)
NAME_RE = re.compile(r"^\s{9,}(?:[0-9A-Fa-f]{1,16}\s+)*([0-9A-Fa-f]{1,4})\s+(\S+)$")
IDENT_RE = re.compile(r"^[A-Za-z_?][\w?$@.]*$")
# o helper do delay-load e as thunk tails aparecem na tabela e nao sao nomes do runtime.
IGNORED = re.compile(r"^(__delayLoadHelper2|_tailMerge_.*|_load_helper_.*)$")


def recusa(msg: str) -> int:
    print(f"[recusa] {msg}")
    return 1


def main() -> int:
    ap = argparse.ArgumentParser()
    # `action="append"` e obrigatoria: com nargs="+" sozinho, um segundo `--gate` SUBSTITUIRIA
    # o primeiro (argparse default) e a regua ler so o ultimo corpo -- medido na primeira
    # corrida do Passo 3: `[referencia] gate AF_SLOT/AF_REF=15 nomes` com o corpo do pack fora.
    ap.add_argument("--gate", required=True, action="append", nargs="+",
                    help="fonte(s) cujas linhas AF_SLOT/AF_REF/AF_PROMPT_REF nomeiam os simbolos "
                         "referenciados; multi-fonte porque o dll do Passo 3 linka dois corpos")
    ap.add_argument("--absent", required=True)
    ap.add_argument("--defs", required=True, help="pasta com os .def e os .lib de importacao")
    ap.add_argument("--imports", required=True, help="texto de `dumpbin /imports` do exe")
    args = ap.parse_args()

    referenciados: list[str] = []
    for gate_path in [p for grupo in args.gate for p in grupo]:
        with open(gate_path, encoding="utf-8", errors="replace") as fh:
            gate_text = fh.read()
        for line in gate_text.splitlines():
            m = SLOT_RE.match(line)
            if m and m.group(1) not in referenciados:
                referenciados.append(m.group(1))
    with open(args.absent, encoding="utf-8", errors="replace") as fh:
        absent_text = fh.read()
    with open(args.imports, encoding="utf-8", errors="replace") as fh:
        imports_text = fh.read()
    if len(referenciados) < 10:
        return recusa(f"o gate referencia {len(referenciados)} nomes por AF_SLOT; a regua nao tem")

    ausentes: list[str] = []
    for line in absent_text.splitlines():
        m = DATA_RE.match(line.strip())
        if m and m.group(1) not in ausentes:
            ausentes.append(m.group(1))
    if len(ausentes) < 2:
        return recusa(f"o controle negativo declara {len(ausentes)} nomes; nada o que conferir")

    # dono medido: nome -> modulo do .def
    dono: dict[str, str] = {}
    modulos_def: set[str] = set()
    for path in sorted(glob.glob(os.path.join(args.defs, "*.def"))):
        module = ""
        with open(path, encoding="ascii", errors="replace") as fh:
            for line in fh:
                m = DEF_LIB_RE.match(line.rstrip())
                if m:
                    module = m.group(1)
                    modulos_def.add(module.lower())
                    continue
                m = DEF_ROW_RE.match(line.rstrip())
                if not m or not module:
                    continue
                nome = m.group(1)
                if nome in dono and dono[nome] != module:
                    return recusa(
                        f"{nome} esta em {dono[nome]} e em {module}: o linker pegaria o primeiro "
                        "da linha e a tabela de imports mentiria sobre quem exporta"
                    )
                dono[nome] = module
    if not dono:
        return recusa(f"nenhum nome lido dos .def em {args.defs}")

    faltando = [n for n in referenciados if n not in dono]
    if faltando:
        return recusa(f"referenciado sem `.def` que o tenha: {', '.join(faltando[:6])}")

    # o que a tabela de imports do exe diz
    importado: dict[str, set[str]] = {}
    modulo_atual = ""
    for line in imports_text.splitlines():
        m = MOD_RE.match(line.rstrip())
        if m:
            modulo_atual = m.group(1).lower()
            importado.setdefault(modulo_atual, set())
            continue
        m = NAME_RE.match(line.rstrip())
        if m and modulo_atual:
            nome = m.group(2)
            if IDENT_RE.match(nome) and not IGNORED.match(nome):
                importado[modulo_atual].add(nome)
            elif not IDENT_RE.match(nome):
                print(f"[import] linha_nao_lida sob {modulo_atual}: {line.strip()}")
    runtime = {m for m in importado if m in modulos_def}
    if not runtime:
        return recusa(
            f"`dumpbin /imports` nao mostrou nenhum dos modulos do runtime ({', '.join(sorted(modulos_def))})"
        )

    print(f"[referencia] gate AF_SLOT/AF_REF={len(referenciados)} nomes")
    print(f"[referencia] controle_negativo={len(ausentes)} nomes")

    esperado: dict[str, set[str]] = {}
    for nome in referenciados:
        esperado.setdefault(dono[nome].lower(), set()).add(nome)

    erros: list[str] = []
    for modulo in sorted(set(list(esperado.keys()) + list(runtime))):
        quer = esperado.get(modulo, set())
        ve = importado.get(modulo, set())
        print(f"[import] modulo={modulo} referenciado={len(quer)} na_tabela={len(ve)}")
        if quer != ve:
            extra = ""
            if not ve and quer:
                extra = (" -- a tabela nao mostrou NENHUM nome deste modulo; provavel import por "
                         "ordinal (`.def` com ` @n`), que apaga o nome do binario")
            erros.append(
                f"{modulo}: faltam {sorted(quer - ve)[:4]} e sobram {sorted(ve - quer)[:4]}{extra}"
            )

    for nome in ausentes:
        if nome in dono:
            erros.append(f"{nome} esta no export-set medido, mas o controle negativo o declara ausente")
        em = [m for m, nomes in importado.items() if nome in nomes]
        if em:
            erros.append(f"{nome} foi IMPORTADO de {em} — o gate nao seria falsificavel")
        else:
            print(f"[controle] {nome} nao esta na tabela de imports (como o export-set medido diz)")

    if erros:
        for e in erros:
            print(f"[recusa] {e}")
        return 1
    total = sum(len(v) for v in esperado.values())
    print(f"[import] OK referenciados={total} modulos={len(esperado)} nomes_na_tabela={total}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
