#!/bin/bash
# Fixture do dossie 15: sobe o llama-server com o MESMO argv que o
# LlmServerHost._spawn usa, captura o stdout proprio do servidor (e dele que
# sai a linha de VRAM do device Vulkan) e mede o tempo ate o primeiro 200 no
# /health. O servidor fica de pe para a checagem de reuso; o pid vai no log.
set -u
SERVER="/c/Aetherfall/.tools/llama/runtime/llama-server.exe"
MODEL="/c/Aetherfall/models/qwen3.5-4b-q4_k_m.gguf"
KEY="<chave-redactada>"
OUT="/c/Aetherfall/.tools/logs15/manual-server.log"
HDR="Authorization: Bearer $KEY"

nohup "$SERVER" -m "$MODEL" --host 127.0.0.1 --port 8741 -c 4096 -ngl 99 \
    --alias mind-small --reasoning off --api-key "$KEY" > "$OUT" 2>&1 &
PID=$!
disown
echo "fixture  pid=$PID  t0=$(date +%s%3N)"

T0=$(date +%s%3N)
for i in $(seq 1 300); do
    CODE=$(curl -s -o /dev/null -w '%{http_code}' -m 3 -H "$HDR" \
        http://127.0.0.1:8741/health 2>/dev/null)
    NOW=$(date +%s%3N)
    if [ "$CODE" = "200" ]; then
        echo "fixture  health 200 em $((NOW - T0)) ms  (tentativa $i)  pid=$PID"
        exit 0
    fi
    sleep 0.25
done
echo "fixture  NUNCA chegou a 200 em 75 s  ultima resposta='$CODE'  pid=$PID"
exit 1
