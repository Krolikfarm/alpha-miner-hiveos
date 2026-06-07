#!/usr/bin/env bash

# h-stats.sh — reports hashrate / shares / temps to the HiveOS dashboard.
# Tuned for alpha-miner v1.7.x log format, e.g.:
#   gpu=0:NVIDIA GeForce RTX 2060 SUPER component=miner status attempts=20 \
#         hits=7 hashrate_th_s=33.64 tmac_s=33.64 share_equiv_th_s=31.40
#   gpu=0:... component=share submitted job=...
#
# HiveOS expects this script to export:
#   khs   -> total hashrate (we report in H/s, so hs_units="hs")
#   stats -> JSON with per-GPU arrays

. /hive/miners/custom/alpha-miner/h-manifest.conf 2>/dev/null
[[ -z "$CUSTOM_LOG_BASENAME" ]] && CUSTOM_LOG_BASENAME="alpha-miner"

LOG="/hive/miners/custom/alpha-miner/${CUSTOM_LOG_BASENAME}.log"
[[ ! -f "$LOG" ]] && LOG="/var/log/miner/alpha-miner/alpha-miner.log"

# Only look at the recent tail so old lines don't skew the picture
TAIL="$(tail -n 600 "$LOG" 2>/dev/null)"

# ---- Per-GPU hashrate (last status line per gpu index) -------------------
hs="[]"; total=0
gpu_idxs=$(echo "$TAIL" | grep -oE 'gpu=[0-9]+' | grep -oE '[0-9]+' | sort -un)
arr=""
for idx in $gpu_idxs; do
  v=$(echo "$TAIL" | grep -E "gpu=${idx}[:.].*hashrate_th_s=" | tail -n 1 \
        | grep -oE 'hashrate_th_s=[0-9.]+' | head -n 1 | cut -d= -f2)
  [[ -z "$v" ]] && v=0
  arr="${arr}${arr:+,}${v}"
  total=$(awk -v a="$total" -v b="$v" 'BEGIN{printf "%.4f", a+b}')
done
[[ -n "$arr" ]] && hs="[$arr]"

# HiveOS wants khs; we report raw H/s so convert (khs = hs/1000)
khs=$(awk -v t="$total" 'BEGIN{printf "%.6f", t/1000}')
[[ -z "$khs" ]] && khs=0

# ---- Accepted / rejected shares -----------------------------------------
ac=$(echo "$TAIL" | grep -cE 'component=share submitted')
rj=$(echo "$TAIL" | grep -icE 'reject')
[[ -z "$ac" ]] && ac=0
[[ -z "$rj" ]] && rj=0

# ---- GPU temps / fans / bus ids from HiveOS ------------------------------
gpu_stats=$(cat /run/hive/gpu-stats.json 2>/dev/null)
if [[ -n "$gpu_stats" ]]; then
  temps=$(echo "$gpu_stats" | jq -c '[.temp[]? | tonumber? // 0]')
  fans=$(echo "$gpu_stats"  | jq -c '[.fan[]?  | tonumber? // 0]')
  busids=$(echo "$gpu_stats"| jq -c '[.busids[]? | split(":")[0] | tonumber? // 0]')
else
  temps="[]"; fans="[]"; busids="[]"
fi

# Make sure hs has at least one element so the rig shows as hashing
[[ "$hs" == "[]" ]] && hs="[0]"

stats=$(jq -nc \
  --argjson hs "$hs" \
  --argjson temp "$temps" \
  --argjson fan "$fans" \
  --argjson busids "$busids" \
  --arg ac "$ac" --arg rj "$rj" \
  --arg uptime "$(awk '{print int($1)}' /proc/uptime)" \
  '{
     hs: $hs,
     hs_units: "hs",
     temp: $temp,
     fan: $fan,
     bus_numbers: $busids,
     uptime: ($uptime|tonumber),
     ar: [($ac|tonumber), ($rj|tonumber)],
     algo: "pearlhash"
   }')

echo "khs=$khs"
echo "stats=$stats"
