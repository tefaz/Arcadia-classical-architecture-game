#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [[ -x "$project_dir/builds/Arcadia-Linux/arcadia.x86_64" ]]; then
    exec "$project_dir/builds/Arcadia-Linux/arcadia.x86_64" "$@"
fi
case "$(uname -m)" in
    x86_64) engine_name="Godot_v4.7.2-stable_linux.x86_64" ;;
    aarch64|arm64) engine_name="Godot_v4.7.2-stable_linux.arm64" ;;
    *) echo "Use a Godot 4.5+ build for your CPU to open project.godot." >&2; exit 1 ;;
esac
if [[ -x "$project_dir/tools/$engine_name" ]]; then
    exec "$project_dir/tools/$engine_name" --path "$project_dir" "$@"
fi
for candidate in godot4 godot; do
    if command -v "$candidate" >/dev/null 2>&1 && [[ "$("$candidate" --version)" == 4.* ]]; then
        exec "$candidate" --path "$project_dir" "$@"
    fi
done
echo "Godot 4 is needed. Run ./tools/setup.sh once, then ./launch.sh." >&2
exit 1
