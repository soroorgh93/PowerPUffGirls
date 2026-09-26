#!/usr/bin/env bash
# Start EdgeGuardian on the ZGX Nano against the locally served model (ZRT on :8080 by default).
#   bash scripts/run_gb10.sh            # desktop app window on the GB10's display
#   WEB=1 bash scripts/run_gb10.sh      # browser UI on :8600 (for ssh -L 8600:127.0.0.1:8600 from a laptop)
#   GUARDIAN_LLM__BASE_URL=http://127.0.0.1:8000/v1 bash scripts/run_gb10.sh   # plain vLLM port
set -euo pipefail
cd "$(dirname "$0")/.."
source .venv-gb10/bin/activate
PROFILE="${PROFILE:-gb10}"
PORT="${PORT:-8600}"
BASE="${GUARDIAN_LLM__BASE_URL:-http://127.0.0.1:8080/v1}"
if ! curl -s "$BASE/models" | grep -q '"id"'; then
  echo "(model endpoint $BASE not reachable - start it with: bash scripts/launch_gb10_llm.sh; the app still runs with the deterministic planner)"
fi
if [[ "${WEB:-0}" == "1" ]]; then
  exec python -m edge_guardian serve --profile "$PROFILE" --host 0.0.0.0 --port "$PORT"
fi
exec python -m edge_guardian desktop --profile "$PROFILE" --port "$PORT"
