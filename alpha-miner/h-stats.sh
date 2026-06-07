#!/usr/bin/env bash

# h-stats.sh — reports hashrate / shares / temps to the HiveOS dashboard.
#
# HiveOS expects this script to export two variables:
#   khs   -> total hashrate in kH/s (a single number)
#   stats -> a JSON string with per-GPU arrays
#
# NOTE: alpha-miner's exact log wording may differ. The regexes below try a few
# common patterns. If the dashboard shows 0, run the rig, copy a few lines of
# real output from /var/log/miner/alpha-miner/alpha-miner.log and tweak the
# grep/awk patterns to match.

. /hive/miners/custom/alpha-miner/h-manifest.conf 2>/dev/null

LOG="${CUSTOM_LOG_BASENAME}.log"
[[ ! -f "$LOG" ]] && LOG="/var/log/miner/alpha-miner/alpha-miner.log"

# ---- Hashrate (last reported value) -------------------------------------
# Matches e.g. "12.34 MH/s", "1200 kH/s", "950000 H/s", "Hashrate: 12.3M"
line=$(grep -iE 'h/?s|hashrate|speed' "$LOG" 2>/dev/null | tail -n 1)

num=$(echo "$line" | grep -oiE '[0-9]+(\.[0-9]+)?\s*[kmg]?h/?s' | tail -n 1)
val=$(echo "$num" | grep -oE '[0-9]+(\.[0-9]+)?' | head -n 1)
unit=$(echo "$num" | grep -oiE '[kmg]?h/?s' | head -n 1 | tr 'A-Z' 'a-z')
[[ -z "$val" ]] && val=0

# Normalize everything to kH/s for HiveOS
case "$unit" in
  gh*) khs=$(echo "$val * 1000000" | bc -l) ;;
  mh*) khs=$(echo "$val * 1000"    | bc -l) ;;
  kh*) khs="$val" ;;
  *)   khs=$(echo "$val / 1000"    | bc -l) ;;   # plain H/s
esac
[[ -z "$khs" ]] && khs=0

# ---- Accepted / rejected shares -----------------------------------------
ac=$(grep -icE 'accept' "$LOG" 2>/dev/null);  [[ -z "$ac" ]] && ac=0
rj=$(grep -icE 'reject' "$LOG" 2>/dev/null);  [[ -z "$rj" ]] && rj=0

# ---- GPU temps / fans / bus ids from HiveOS ------------------------------
gpu_stats=$(cat /run/hive/gpu-stats.json 2>/dev/null)
if [[ -n "$gpu_stats" ]]; then
  temps=$(echo "$gpu_stats" | jq -c '.temp // []')
  fans=$(echo "$gpu_stats"  | jq -c '.fan // []')
  busids=$(echo "$gpu_stats"| jq -c '[.busids[]? | split(":")[0] | tonumber? // 0]')
else
  temps="[]"; fans="[]"; busids="[]"
fi

# Number of GPUs (default 1 so the dashboard shows the rig as hashing)
gpu_count=$(echo "$temps" | jq 'length')
[[ -z "$gpu_count" || "$gpu_count" -eq 0 ]] && gpu_count=1

# Spread total hashrate evenly across GPUs for the per-card display
per=$(echo "$khs / $gpu_count" | bc -l)
hs=$(python3 -c "print([round($per,3)]*$gpu_count)" 2>/dev/null | tr "'" '"')
[[ -z "$hs" ]] && hs="[$khs]"

stats=$(jq -nc \
  --argjson hs "$hs" \
  --argjson temp "$temps" \
  --argjson fan "$fans" \
  --argjson busids "$busids" \
  --arg ac "$ac" --arg rj "$rj" \
  --arg uptime "$(awk '{print int($1)}' /proc/uptime)" \
  '{
     hs: $hs,
     hs_units: "khs",
     temp: $temp,
     fan: $fan,
     bus_numbers: $busids,
     uptime: ($uptime|tonumber),
     ar: [($ac|tonumber), ($rj|tonumber)],
     algo: "alpha"
   }')

# Export for HiveOS
echo "khs=$khs"
echo "stats=$stats"
