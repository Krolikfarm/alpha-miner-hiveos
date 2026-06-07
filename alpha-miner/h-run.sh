#!/usr/bin/env bash

cd "`dirname $0`"
[[ `pwd` != */hive/miners/custom/* ]] && cd /hive/miners/custom/alpha-miner

# Load manifest variables (CUSTOM_CONFIG_FILENAME, CUSTOM_LOG_BASENAME, ...)
. h-manifest.conf
[[ -z "$CUSTOM_CONFIG_FILENAME" ]] && CUSTOM_CONFIG_FILENAME="alpha-miner.conf"
[[ -z "$CUSTOM_LOG_BASENAME" ]] && CUSTOM_LOG_BASENAME="alpha-miner"

# Download the miner binary on first run if it isn't bundled in the package
if [[ ! -s alpha-miner ]]; then
  echo "alpha-miner binary not found, downloading..."
  curl -L -o alpha-miner https://pearl.alphapool.tech/downloads/alpha-miner
fi
chmod +x alpha-miner

# Read the argument string produced by h-config.sh
ARGS="$(cat "$CUSTOM_CONFIG_FILENAME" 2>/dev/null)"

# Fallback: if the config is empty (h-config.sh didn't run), rebuild the args
# directly from the CUSTOM_* variables HiveOS exports to the miner.
if [[ -z "$ARGS" ]]; then
  POOL="$CUSTOM_URL"
  [[ "$POOL" != stratum* && "$POOL" != *://* ]] && POOL="stratum+tcp://$POOL"
  WK="$WORKER_NAME"; [[ -z "$WK" ]] && WK="rig01"
  PASS="$CUSTOM_PASS"; [[ -z "$PASS" ]] && PASS="x"
  ARGS="--pool $POOL --address $CUSTOM_TEMPLATE --worker $WK --password \"$PASS\""
  [[ -n "$CUSTOM_USER_CONFIG" ]] && ARGS+=" $CUSTOM_USER_CONFIG"
fi

echo "[h-run] launching: ./alpha-miner $ARGS"

# Launch the miner. Output is sent to the HiveOS log so h-stats.sh can parse it.
eval "./alpha-miner $ARGS" 2>&1 | tee "$CUSTOM_LOG_BASENAME.log"
