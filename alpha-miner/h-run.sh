#!/usr/bin/env bash

cd "`dirname $0`"
[[ `pwd` != */hive/miners/custom/* ]] && cd /hive/miners/custom/alpha-miner

# Load manifest variables (CUSTOM_CONFIG_FILENAME, CUSTOM_LOG_BASENAME, ...)
. h-manifest.conf

# Download the miner binary on first run if it isn't bundled in the package
if [[ ! -f alpha-miner ]]; then
  echo "alpha-miner binary not found, downloading..."
  curl -L -o alpha-miner https://pearl.alphapool.tech/downloads/alpha-miner
fi
chmod +x alpha-miner

# Read the argument string produced by h-config.sh
ARGS="$(cat "$CUSTOM_CONFIG_FILENAME")"

# Launch the miner. Output is sent to the HiveOS log so h-stats.sh can parse it.
eval "./alpha-miner $ARGS" 2>&1 | tee "$CUSTOM_LOG_BASENAME.log"
