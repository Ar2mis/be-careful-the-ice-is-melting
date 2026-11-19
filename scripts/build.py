#!/usr/bin/env python3
"""Import, test, and export the actual Godot game. No JS gameplay substitute."""
import os
import gzip
from pathlib import Path
import shutil
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
GODOT = os.environ.get("GODOT_BIN") or shutil.which("godot")
if not GODOT:
    candidates = [Path.home() / "Applications/Godot.app/Contents/MacOS/Godot",
                  Path("/Applications/Godot.app/Contents/MacOS/Godot")]
    GODOT = next((str(p) for p in candidates if p.exists()), None)
if not GODOT:
    sys.exit("Install Godot 4.7.2 and matching Web export templates; or set GODOT_BIN.")

def run(*args):
    command = [GODOT, "--headless", "--path", str(ROOT / "game"), *args]
    result = subprocess.run(command, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    print(result.stdout)
    if result.returncode or "SCRIPT ERROR:" in result.stdout or "ERROR:" in result.stdout:
        sys.exit(result.returncode or 1)

run("--editor", "--import", "--quit")
run("--script", "res://tests/test_routes.gd")
run("--quit-after", "3")
(ROOT / "dist").mkdir(exist_ok=True)
run("--export-release", "Web", str(ROOT / "dist/index.html"))
required = ["index.html", "index.js", "index.wasm", "index.pck"]
for name in required:
    assert (ROOT / "dist" / name).is_file(), f"Missing export: {name}"
assert "$GODOT_" not in (ROOT / "dist/index.html").read_text()
(ROOT / "artifacts").mkdir(exist_ok=True)
with zipfile.ZipFile(ROOT / "artifacts/melt-shift-web.zip", "w", zipfile.ZIP_DEFLATED) as archive:
    for path in sorted((ROOT / "dist").iterdir()):
        if path.is_file() and path.suffix != ".gz":
            archive.write(path, path.name)

# Sites limits each static asset to 25 MiB. Keep the normal Godot export in
# the itch.io ZIP; serve a gzip engine in dist, decoded by the browser loader.
# Patch one version-pinned loader line, never the game code or global fetch.
wasm = ROOT / "dist/index.wasm"
compressed = gzip.compress(wasm.read_bytes(), compresslevel=9, mtime=0)
assert len(compressed) < 25 * 1024 * 1024
loader = ROOT / "dist/index.js"
source = loader.read_text()
original = "loadPromise = preloader.loadPromise(`${loadPath}.wasm`, size, true);"
assert source.count(original) == 1, "Godot loader changed; review gzip integration."
replacement = """loadPromise = preloader.loadPromise(`${loadPath}.wasm.gz`, COMPRESSED_SIZE, true)
                .then(async (response) => {
                    const bytes = new Uint8Array(await response.arrayBuffer());
                    // Some hosts decode Content-Encoding automatically. Accept
                    // both raw WASM and gzip, without relying on server headers.
                    let body = bytes;
                    if (bytes[0] === 0x1f && bytes[1] === 0x8b) {
                        body = new Blob([bytes]).stream().pipeThrough(new DecompressionStream('gzip'));
                    }
                    return new Response(body, {headers: {'content-type': 'application/wasm'}});
                });""".replace("COMPRESSED_SIZE", str(len(compressed)))
loader.write_text(source.replace(original, replacement))
wasm.with_suffix(".wasm.gz").write_bytes(compressed)
assert gzip.decompress(compressed) == wasm.read_bytes()
wasm.unlink()
print(f"Hosted engine: {len(compressed) / 1024 / 1024:.1f} MiB (lossless gzip)")
print("Ready: dist/index.html and standard export artifacts/melt-shift-web.zip")

