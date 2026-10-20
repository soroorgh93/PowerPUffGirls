#!/usr/bin/env bash
# Serve the local VLM/LLM on the ZGX Nano with HP ZRT (the vLLM wrapper shown in the HP hackathon
# walkthrough: sudo zrt setup -> zrt serve <model> -> OpenAI API on http://127.0.0.1:8080/v1).
#
#   bash scripts/launch_gb10_llm.sh                        # Qwen/Qwen2.5-VL-7B-Instruct (pulled once, ~16 GB)
#   MODEL=Qwen/Qwen3-VL-8B-Instruct bash scripts/launch_gb10_llm.sh
#   GPU_FRACTION=0.5 bash scripts/launch_gb10_llm.sh       # share of the 128 GB unified memory vLLM may reserve
#   MODE=docker bash scripts/launch_gb10_llm.sh            # plain vLLM container instead of ZRT (port 8000)
#
# Why GPU_FRACTION: ZRT "auto-calculates" a fraction from a very pessimistic VRAM estimate (~0.66 = 80 GB for a
# 7B model). If anything else holds memory (another zrt service, a stale vLLM, someone's Ollama) vLLM refuses to
# start with "Free memory on device ... is less than desired GPU memory utilization". A 7B vision model in bf16
# is ~16 GB of weights; 0.35 (~42 GB) leaves ample KV cache for 12-image prompts and room for the app's own
# models (whisper, CLIP, CLAP, YOLO ~8 GB).
#
# Any OpenAI-compatible vision model works; set GUARDIAN_LLM__MODEL to the served name if it differs.
set -euo pipefail
MODEL="${MODEL:-Qwen/Qwen2.5-VL-7B-Instruct}"
PORT="${PORT:-8080}"
MODE="${MODE:-zrt}"
GPU_FRACTION="${GPU_FRACTION:-0.35}"

free_gib() {  # free unified memory in GiB as nvidia-smi sees it (falls back to /proc/meminfo)
  local mib
  mib=$(nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits 2>/dev/null | head -1 || true)
  if [[ -n "${mib:-}" && "$mib" =~ ^[0-9]+$ ]]; then echo $((mib / 1024)); else awk '/MemAvailable/ {printf "%d", $2/1048576}' /proc/meminfo; fi
}

if [[ "$MODE" == "zrt" ]]; then
  command -v zrt >/dev/null || { echo "zrt not installed on this box: sudo zrt setup (HP Z Runtime) - see docs/GB10_RUNBOOK.md"; exit 1; }
  zrt config set proxy.auth.type none >/dev/null 2>&1 || true
  zrt config set proxy.tls.enabled false >/dev/null 2>&1 || true
  if curl -s "http://127.0.0.1:${PORT}/v1/models" | grep -q '"id"'; then
    echo "== a model is already being served on :${PORT}:"; curl -s "http://127.0.0.1:${PORT}/v1/models"; echo; exit 0
  fi
  FREE=$(free_gib)
  echo "== free unified memory: ${FREE} GiB (a 7B vision model needs ~25 GiB with GPU_FRACTION=${GPU_FRACTION})"
  if [[ "${FREE:-0}" -lt 30 ]]; then
    echo "!! Not much memory is free. Something else is holding it. Check and stop it first:"
    echo "     zrt status            -> another model served by ZRT?  stop it:  zrt stop <service name>"
    echo "     nvidia-smi            -> stale vllm / python / ollama processes?  kill your own:  pkill -f vllm"
    echo "     free -g               -> system RAM is the same 128 GB pool on the GB10"
    zrt status 2>/dev/null || true
    nvidia-smi --query-compute-apps=pid,process_name,used_memory --format=csv 2>/dev/null || true
  fi
  echo "== zrt serve $MODEL --gpu-memory-fraction $GPU_FRACTION   (OpenAI API -> http://127.0.0.1:${PORT}/v1)"
  if ! zrt serve "$MODEL" --gpu-memory-fraction "$GPU_FRACTION"; then
    echo "!! zrt serve failed. Usual fixes:"
    echo "     zrt stop <service>                                  # free memory held by another served model"
    echo "     GPU_FRACTION=0.25 bash scripts/launch_gb10_llm.sh   # smaller reservation (still fine for a 7B model)"
    echo "     zrt logs   /   tail -50 /opt/hp/zrt/run/vllm-*.log  # the real error"
    exit 1
  fi
  echo "== waiting for the backend to become healthy (large models take a few minutes)"
  for i in $(seq 1 240); do
    if curl -s "http://127.0.0.1:${PORT}/v1/models" | grep -q '"id"'; then echo "== ready"; zrt status || true; exit 0; fi
    sleep 5
  done
  echo "backend did not come up; check: zrt status / zrt logs"; exit 1
else
  echo "== docker vllm/vllm-openai $MODEL on :${PORT}"
  exec docker run --rm --gpus all --ipc=host -p "127.0.0.1:${PORT}:8000" \
    -v "$HOME/.cache/huggingface:/root/.cache/huggingface" -e HF_TOKEN="${HF_TOKEN:-}" \
    vllm/vllm-openai:latest "$MODEL" --host 0.0.0.0 --port 8000 --max-model-len 32768 \
    --limit-mm-per-prompt '{"image":12}' --gpu-memory-utilization "$GPU_FRACTION"
fi
