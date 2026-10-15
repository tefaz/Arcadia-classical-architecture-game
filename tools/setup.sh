#!/usr/bin/env bash
set -euo pipefail
tools_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
case "$(uname -m)" in
    x86_64) cpu="x86_64" ;;
    aarch64|arm64) cpu="arm64" ;;
    *) echo "Download a Godot 4.5+ build for your CPU from godotengine.org." >&2; exit 1 ;;
esac
engine_name="Godot_v4.7.2-stable_linux.$cpu"
if [[ -x "$tools_dir/$engine_name" ]]; then
    echo "Godot is ready. Run ./launch.sh."
    exit 0
fi
curl -fL --retry 2 "https://godot-releases.nbg1.your-objectstorage.com/4.7.2-stable/$engine_name.zip" -o "$tools_dir/godot-linux.zip"
unzip -o "$tools_dir/godot-linux.zip" -d "$tools_dir"
chmod +x "$tools_dir/$engine_name"
echo "Godot is ready. Run ./launch.sh."
