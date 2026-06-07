#!/usr/bin/env bash

# h-config.sh — builds the alpha-miner command line from the Flight Sheet fields.
# HiveOS passes these variables from the "Custom" miner setup:
#   CUSTOM_URL          -> Pool URL          (us2.alphapool.tech:5566)
#   CUSTOM_TEMPLATE     -> Wallet and worker  (prl1pYOUR_ADDRESS)
#   CUSTOM_PASS         -> Pass               (x;d=65536)
#   CUSTOM_USER_CONFIG  -> Extra config arguments (free-form, optional)
#   WORKER_NAME         -> the rig's worker name in HiveOS

# Make sure the pool URL carries the stratum+tcp:// prefix
POOL="$CUSTOM_URL"
[[ "$POOL" != stratum* && "$POOL" != *://* ]] && POOL="stratum+tcp://$POOL"

# Worker: use the HiveOS worker name (fallback to "rig01")
WK="$WORKER_NAME"
[[ -z "$WK" ]] && WK="rig01"

# Build argument string
ARGS="--pool $POOL"
ARGS+=" --address $CUSTOM_TEMPLATE"
ARGS+=" --worker $WK"
ARGS+=" --password \"$CUSTOM_PASS\""

# Any extra flags typed into "Extra config arguments" are appended verbatim
[[ -n "$CUSTOM_USER_CONFIG" ]] && ARGS+=" $CUSTOM_USER_CONFIG"

echo "$ARGS" > "$CUSTOM_CONFIG_FILENAME"
