#!/usr/bin/env bash
# =============================================================
#  demo_loop.sh — Base Mainnet Prediction Market Demo
#  发送持续撮合交易，每隔 INTERVAL 秒发一笔 matchOrders 上链
#
#  前置条件:
#    1. 已在 .env 中设置以下变量 (运行 02_DeployBase.s.sol 后获得):
#         PRI_KEY, MAKER_PRIVATE_KEY, TAKER_PRIVATE_KEY
#         CTF_EXCHANGE, CTF, COLLATERAL, TOKEN_ID_YES, CONDITION_ID
#         BASE_RPC  (e.g. https://mainnet.base.org)
#    2. 已安装 Foundry (forge 命令可用)
#
#  运行方式:
#    bash script/base/demo_loop.sh
#    bash script/base/demo_loop.sh --interval 5   # 每 5 秒一笔
#    bash script/base/demo_loop.sh --count 20     # 只跑 20 笔
# =============================================================

set -euo pipefail

# ── 加载 .env ─────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"

if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  export $(grep -v '^#' "$ENV_FILE" | xargs)
  echo "[demo_loop] Loaded .env from $ENV_FILE"
else
  echo "[ERROR] .env not found at $ENV_FILE"
  exit 1
fi

# ── 参数解析 ──────────────────────────────────────────────────
INTERVAL=10   # seconds between each match tx
MAX_COUNT=0   # 0 = infinite loop

while [[ $# -gt 0 ]]; do
  case "$1" in
    --interval|-i) INTERVAL="$2"; shift 2;;
    --count|-n)    MAX_COUNT="$2"; shift 2;;
    *) echo "Unknown arg: $1"; exit 1;;
  esac
done

# ── 验证必需变量 ──────────────────────────────────────────────
REQUIRED_VARS=(PRI_KEY CTF_EXCHANGE TOKEN_ID_YES BASE_RPC)
for var in "${REQUIRED_VARS[@]}"; do
  if [[ -z "${!var:-}" ]]; then
    echo "[ERROR] Missing required env var: $var"
    echo "  Run 00_DeployAll.s.sol first and add its output to .env"
    exit 1
  fi
done

# ── 打印 Demo 信息 ────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║   Prediction Market Demo — Base Mainnet              ║"
echo "║   Continuous Order Matching Loop                     ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
echo "  Exchange  : ${CTF_EXCHANGE}"
echo "  RPC       : ${BASE_RPC}"
echo "  Interval  : ${INTERVAL}s"
echo "  Max count : ${MAX_COUNT} (0 = infinite)"
echo ""
echo "  Explorer  : https://basescan.org/address/${CTF_EXCHANGE}"
echo ""
echo "  Press Ctrl+C to stop"
echo ""

# ── 主循环 ───────────────────────────────────────────────────
run=0
while true; do
  run=$((run + 1))

  if [[ $MAX_COUNT -gt 0 && $run -gt $MAX_COUNT ]]; then
    echo ""
    echo "[demo_loop] Reached max count ($MAX_COUNT). Stopping."
    break
  fi

  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "[$(date '+%H:%M:%S')] Run #${run} — Broadcasting matchOrders..."
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  # Pass run counter so each tx gets a unique salt
  RUN_COUNTER=$run forge script \
    "$ROOT_DIR/script/base/01_MatchOnce.s.sol:MatchOnce" \
    --rpc-url "$BASE_RPC" \
    --broadcast \
    --private-key "$PRI_KEY" \
    -vv \
    2>&1 | tee /tmp/match_run_${run}.log | grep -E "(MatchOnce|matchOrders|SUCCESS|ERROR|error|fail|Block|Run #)"

  echo ""
  echo "[$(date '+%H:%M:%S')] ✅  Run #${run} done — sleeping ${INTERVAL}s..."
  echo ""
  sleep "$INTERVAL"
done
