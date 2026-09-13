#!/bin/bash

LOCALDIR=`cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd`
TOOLS_DIR="$LOCALDIR/tools"

mkdir -p "$TOOLS_DIR"

# Skip remote git pull in CI runners to prevent detached HEAD and merge conflict failures
if [ -z "$GITHUB_ACTIONS" ] && [ -z "$CI" ]; then
    echo "Updating repository and submodules..."
    git submodule update --init --recursive || true
    git pull --recurse-submodules || true
else
    echo "CI environment detected: syncing submodules safely..."
    git submodule update --init --recursive || true
fi

# Ensure Firmware_extractor is cloned if missing
if [[ ! -d "$TOOLS_DIR/Firmware_extractor" ]]; then
    echo "Cloning Firmware_extractor..."
    git clone -q https://github.com/erfanoabdi/Firmware_extractor "$TOOLS_DIR"/Firmware_extractor || true
elif [ -z "$GITHUB_ACTIONS" ] && [ -z "$CI" ]; then
    git -C "$TOOLS_DIR"/Firmware_extractor fetch origin || true
    git -C "$TOOLS_DIR"/Firmware_extractor reset --hard origin/master || true
fi
