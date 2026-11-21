#!/bin/bash
# Checagem 5 do dossie 15: o servidor do jogo morre por causa EXTERNA depois do
# primeiro 200. O host tem de ver a morte, retentar uma unica vez e voltar a
# ficar pronto — sem loop. Quem mata e este script, de fora do processo do jogo,
# porque morte interna nao e o que se quer fabricar aqui.
set -u
cd /c/Aetherfall/.tools/wt-code-15 || exit 1
ENGINE="/c/Aetherfall/.tools/Godot_v4.7.2-stable_win64_console.exe"
LOG="/c/Aetherfall/.tools/logs15/probe-death.log"
SRV="C:/Aetherfall/.tools/llama/runtime/llama-server.exe"
MOD="C:/Aetherfall/models/qwen3.5-4b-q4_k_m.gguf"

"$ENGINE" --headless --path . tests/llm_server_boot_probe.tscn -- \
    --mode=death --llm-server="$SRV" --llm-model="$MOD" > "$LOG" 2>&1 &
PROBE=$!
echo "death  probe pid=$PROBE"

CHILD=""
for i in $(seq 1 120); do
    if grep -q "esperando morte externa do pid" "$LOG" 2>/dev/null; then
        CHILD=$(sed -n 's/.*esperando morte externa do pid \([0-9]*\).*/\1/p' "$LOG" | head -1)
        break
    fi
    if ! kill -0 "$PROBE" 2>/dev/null; then
        echo "death  o probe terminou antes de pedir a morte"
        cat "$LOG"; exit 1
    fi
    sleep 1
done
if [ -z "$CHILD" ]; then echo "death  nunca vi o pid do filho"; cat "$LOG"; exit 1; fi

echo "death  matando o filho $CHILD por causa externa (taskkill)"
taskkill //PID "$CHILD" //F 2>&1
wait "$PROBE"
echo "death  probe saiu com $?"
cat "$LOG"
