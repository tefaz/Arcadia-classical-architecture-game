#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
engine="$project_dir/tools/Godot_v4.7.2-stable_linux.$(uname -m)"
if [[ ! -x "$engine" ]]; then engine="${GODOT_BIN:-godot}"; fi
test_dir="$(mktemp -d /tmp/arcadia-tests.XXXXXX)"
export XDG_DATA_HOME="$test_dir/data"
export XDG_CONFIG_HOME="$test_dir/config"
export XDG_CACHE_HOME="$test_dir/cache"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
exec "$engine" --headless --path "$project_dir" --script res://tests/run.gd -- --test
