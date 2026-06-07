#!/usr/bin/env bash

# h-config.sh — builds the alpha-miner command line from the Flight Sheet fields.
# HiveOS passes these variables from the "Custom" miner setup:
#   CUSTOM_URL          -> Pool URL          (eu1.alphapool.tech:5566)
#   CUSTOM_TEMPLATE     -> Wallet template    (prl1pYOUR_ADDRESS, from %WAL%)
#   CUSTOM_PASS         -> Pass               (x;d=65536)
#   CUSTOM_USER_CONFIG  -> Extra config arguments (free-form, optional)
#   WORKER_NAME         -> the rig's worker name in HiveOS

cd "`dirname $0`"
[[ `pwd` != */hive/miners/custom/* ]] && cd /hive/miners/custom/alpha-miner

# Pull CUSTOM_CONFIG_FILENAME / CUSTOM_NAME from the manifest (not always
# inherited from the parent environment when run as a subprocess).
. h-manifest.conf
[[ -z "$CUSTOM_CONFIG_FILENAME" ]] && CUSTOM_CONFIG_FILENAME="alpha-miner.conf"

# Make sure the pool URL carries the stratum+tcp:// prefix
POOL="$CUSTOM_URL"
[[ "$POOL" != stratum* && "$POOL" != *://* ]] && POOL="stratum+tcp://$POOL"

# Worker: use the HiveOS worker name (fallback to "rig01")
WK="$WORKER_NAME"
[[ -z "$WK" ]] && WK="rig01"

# Password: alpha-miner defaults to "x" if empty
PASS="$CUSTOM_PASS"
[[ -z "$PASS" ]] && PASS="x"

# Build argument string
ARGS="--pool $POOL"
ARGS+=" --address $CUSTOM_TEMPLATE"
ARGS+=" --worker $WK"
ARGS+=" --password \"$PASS\""

# Any extra flags typed into "Extra config arguments" are appended verbatim
[[ -n "$CUSTOM_USER_CONFIG" ]] && ARGS+=" $CUSTOM_USER_CONFIG"

echo "$ARGS" > "$CUSTOM_CONFIG_FILENAME"
echo "[h-config] wrote $CUSTOM_CONFIG_FILENAME: $ARGS"
