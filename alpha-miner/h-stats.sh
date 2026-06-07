#!/usr/bin/env bash

# h-stats.sh — reports hashrate / shares / temps to the HiveOS dashboard.
# Tuned for alpha-miner v1.7.x log format, e.g.:
#   gpu=0:NVIDIA GeForce RTX 2060 SUPER component=miner status attempts=20 \
#         hits=7 hashrate_th_s=33.64 tmac_s=33.64 share_equiv_th_s=31.40
#   gpu=0:... component=share submitted job=...
#
# Per-GPU hashrate is aligned to the NVIDIA cards' PCI bus ids (via nvidia-smi)
# so an iGPU (e.g. Intel HD Graphics) in the rig does not shift the indices.
#
# Exports:
#   khs   -> total hashrate (reported in H/s, so hs_units="hs")
#   stats -> JSON with per-GPU arrays aligned by bus_numbers

. /hive/miners/custom/alpha-miner/h-manifest.conf 2>/dev/null
[[ -z "$CUSTOM_LOG_BASENAME" ]] && CUSTOM_LOG_BASENAME="alpha-miner"

LOG="/hive/miners/custom/alpha-miner/${CUSTOM_LOG_BASENAME}.log"
[[ ! -f "$LOG" ]] && LOG="/var/log/miner/alpha-miner/alpha-miner.log"

TAIL="$(tail -n 600 "$LOG" 2>/dev/null)"

# ---- Per-GPU hashrate from the log (by miner gpu index) ------------------
declare -A HR
gpu_idxs=$(echo "$TAIL" | grep -oE 'gpu=[0-9]+' | grep -oE '[0-9]+' | sort -un)
for idx in $gpu_idxs; do
  v=$(echo "$TAIL" | grep -E "gpu=${idx}[:.].*hashrate_th_s=" | tail -n 1 \
        | grep -oE 'hashrate_th_s=[0-9.]+' | head -n 1 | cut -d= -f2)
  [[ -z "$v" ]] && v=0
  HR[$idx]=$v
done

# ---- NVIDIA cards in index order: bus id + temp + fan -------------------
# nvidia-smi enumerates the same NVIDIA cards the miner uses (gpu=0,1,...).
hs_arr=(); bus_arr=(); temp_arr=(); fan_arr=(); total=0; i=0
while IFS=',' read -r temp fan busid; do
  temp=$(echo "$temp" | tr -dc '0-9')
  fan=$(echo "$fan"   | tr -dc '0-9')
  # PCI bus id like 00000000:02:00.0 -> hex "02" -> decimal bus number
  bushex=$(echo "$busid" | tr -d ' ' | cut -d: -f2)
  busdec=$(printf "%d" "0x${bushex}" 2>/dev/null); [[ -z "$busdec" ]] && busdec=0

  hr=${HR[$i]}; [[ -z "$hr" ]] && hr=0
  hs_arr+=("$hr"); bus_arr+=("$busdec")
  temp_arr+=("${temp:-0}"); fan_arr+=("${fan:-0}")
  total=$(awk -v a="$total" -v b="$hr" 'BEGIN{printf "%.4f", a+b}')
  i=$((i+1))
done < <(nvidia-smi --query-gpu=temperature.gpu,fan.speed,pci.bus_id \
           --format=csv,noheader,nounits 2>/dev/null)

# Fallback: no nvidia-smi output -> just emit the log hashrates, no bus map
if [[ ${#hs_arr[@]} -eq 0 ]]; then
  for idx in $gpu_idxs; do
    hs_arr+=("${HR[$idx]}")
    total=$(awk -v a="$total" -v b="${HR[$idx]}" 'BEGIN{printf "%.4f", a+b}')
  done
fi

# Join helper
join() { local IFS=,; echo "$*"; }
hs_json="[$(join "${hs_arr[@]}")]";   [[ "$hs_json" == "[]" ]] && hs_json="[0]"
bus_json="[$(join "${bus_arr[@]}")]"; [[ "$bus_json" == "[]" ]] && bus_json="[]"
temp_json="[$(join "${temp_arr[@]}")]"
fan_json="[$(join "${fan_arr[@]}")]"

khs=$(awk -v t="$total" 'BEGIN{printf "%.6f", t/1000}')
[[ -z "$khs" ]] && khs=0

# ---- Accepted / rejected shares -----------------------------------------
ac=$(echo "$TAIL" | grep -cE 'component=share submitted'); [[ -z "$ac" ]] && ac=0
rj=$(echo "$TAIL" | grep -icE 'reject');                  [[ -z "$rj" ]] && rj=0

stats=$(jq -nc \
  --argjson hs "$hs_json" \
  --argjson temp "$temp_json" \
  --argjson fan "$fan_json" \
  --argjson busids "$bus_json" \
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
