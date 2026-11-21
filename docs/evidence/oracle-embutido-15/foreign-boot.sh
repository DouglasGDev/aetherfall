#!/bin/bash
# Fixture "estrangeiro": um llama-server na 8741 com OUTRA chave e outro alias,
# que e o caso real de uma maquina compartilhada. O hospedeiro do jogo tem de
# ler 401, marcar `estrangeiro` e nao matar nem duplicar nada.
set -u
SERVER="/c/Aetherfall/.tools/llama/runtime/llama-server.exe"
MODEL="/c/Aetherfall/models/qwen3.5-4b-q4_k_m.gguf"
OUT="/c/Aetherfall/.tools/logs15/manual-server-foreign.log"

nohup "$SERVER" -m "$MODEL" --host 127.0.0.1 --port 8741 -c 4096 -ngl 99 \
    --alias outro-modelo --reasoning off --api-key chave-de-terceiro \
    > "$OUT" 2>&1 &
PID=$!
disown
echo "estrangeiro  pid=$PID"

T0=$(date +%s%3N)
for i in $(seq 1 200); do
    CODE=$(curl -s -o /dev/null -w '%{http_code}' -m 3 -H "Authorization: Bearer chave-de-terceiro" \
        http://127.0.0.1:8741/health 2>/dev/null)
    if [ "$CODE" = "200" ]; then
        echo "estrangeiro  health 200 em $(( $(date +%s%3N) - T0 )) ms  (a chave do jogo nao serve)"
        # prova de que a chave do jogo e recusada por este servidor:
        C=$(curl -s -o /dev/null -w '%{http_code}' -m 3 -H "Authorization: Bearer aetherfall-mind-2026" \
            http://127.0.0.1:8741/v1/models)
        echo "estrangeiro  /v1/models com a chave do jogo -> $C"
        exit 0
    fi
    sleep 0.25
done
echo "estrangeiro  nunca chegou a 200  ultima='$CODE'"
exit 1
