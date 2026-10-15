#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
engine="$project_dir/tools/Godot_v4.7.2-stable_linux.x86_64"
if [[ ! -x "$engine" ]]; then bash "$project_dir/tools/setup.sh"; fi
bash "$project_dir/tools/fetch-template.sh"
build_dir="$project_dir/builds/Arcadia-Linux"
mkdir -p "$build_dir/licenses"
"$engine" --headless --path "$project_dir" --export-release Linux "$build_dir/arcadia.x86_64"
cp "$project_dir/docs/LICENSE-Godot.txt" "$project_dir/docs/COPYRIGHT-Godot.txt" "$build_dir/licenses/"
cp "$project_dir/assets/fonts/LICENSE-DejaVu.txt" "$project_dir/assets/fonts/LICENSE-FiraSans.txt" "$build_dir/licenses/"
cp "$project_dir/docs/NOTICES.md" "$build_dir/NOTICES.md"
cp "$project_dir/tools/portable-README.md" "$build_dir/README.md"
cp "$project_dir/tools/portable-play.sh" "$build_dir/play.sh"
cp "$project_dir/assets/icon.svg" "$build_dir/icon.svg"
chmod +x "$build_dir/play.sh" "$build_dir/arcadia.x86_64"
tar -C "$project_dir/builds" -czf "$project_dir/builds/Arcadia-Linux-x86_64.tar.gz" Arcadia-Linux
echo "Portable game: $project_dir/builds/Arcadia-Linux-x86_64.tar.gz"
