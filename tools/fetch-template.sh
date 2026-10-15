#!/usr/bin/env bash
set -euo pipefail
tools_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [[ -x "$tools_dir/linux_release.x86_64" ]]; then exit 0; fi
# Pinned official 4.7.2 ZIP: fetch its directory and the x86_64 runtime entry only.
# This avoids downloading templates for every other supported platform.
template_url="https://godot-releases.nbg1.your-objectstorage.com/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz"
curl -fL --retry 2 -r -65536 "$template_url" -o "$tools_dir/template-directory.bin"
curl -fL --retry 2 -r 834960598-863272257 "$template_url" -o "$tools_dir/linux-template.slice"
python3 - "$tools_dir" <<'PY'
from pathlib import Path
import struct, sys, zlib
tools_dir = Path(sys.argv[1])
blob = (tools_dir / 'linux-template.slice').read_bytes()
if blob[:4] != b'PK\x03\x04':
    raise SystemExit('The server did not return the expected ZIP range.')
name_len, extra_len = struct.unpack_from('<HH', blob, 26)
name = blob[30:30+name_len].decode()
if name != 'templates/linux_release.x86_64':
    raise SystemExit('Unexpected template entry.')
size = 28311148
out = zlib.decompress(blob[30+name_len+extra_len:30+name_len+extra_len+size], -15)
directory = (tools_dir / 'template-directory.bin').read_bytes()
index = directory.index(name.encode()) - 46
expected_crc = struct.unpack_from('<I', directory, index+16)[0]
expected_length = struct.unpack_from('<I', directory, index+24)[0]
if zlib.crc32(out) != expected_crc or len(out) != expected_length or out[:4] != b'\x7fELF':
    raise SystemExit('Template integrity check failed.')
target = tools_dir / 'linux_release.x86_64'
target.write_bytes(out)
target.chmod(0o755)
print('Linux runtime extracted and CRC verified.')
PY
