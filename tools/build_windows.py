"""Build a clean, self-contained Windows release without development addons."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]
VERSION = "0.1.2"
PACKAGE = f"LastLight-{VERSION}-Windows-x64"


def reset_generated(path, parent):
    path, parent = path.resolve(), parent.resolve()
    if path.parent != parent or not path.is_relative_to(ROOT):
        raise RuntimeError(f"Refusing to reset unexpected output directory: {path}")
    if path.exists():
        shutil.rmtree(path)
    path.mkdir(parents=True)


def release_project(source):
    result = []
    section = ""
    for line in source.splitlines():
        if line.startswith("["):
            section = line
        if section == "[editor_plugins]" or line.startswith('_mcp_game_helper='):
            continue
        if line.startswith("rendering_device/driver.windows="):
            continue
        if line.startswith("config/features="):
            line = 'config/features=PackedStringArray("4.7", "GL Compatibility")'
        if line.startswith("config/icon="):
            line = 'config/icon="res://assets/sprites/app_icon.svg"'
        result.append(line)
        if line == "[application]":
            result.append(f'config/version="{VERSION}"')
        if line == "[rendering]":
            result.extend(['renderer/rendering_method="gl_compatibility"', 'renderer/rendering_method.mobile="gl_compatibility"'])
    return "\n".join(result) + "\n"


def run(command, log):
    completed = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, encoding="utf-8", errors="replace")
    log.write_text(completed.stdout, encoding="utf-8")
    clean = re.sub(r"\x1b\[[0-9;]*m", "", completed.stdout)
    print(f"{log.name}: exit {completed.returncode}", flush=True)
    for line in clean.splitlines():
        if line.startswith(("ERROR:", "WARNING:", "SCRIPT ERROR:")):
            print(line, flush=True)
    if completed.returncode or "SCRIPT ERROR:" in completed.stdout or "Failed to export" in completed.stdout:
        raise RuntimeError(f"Godot command failed; see {log}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--template", type=Path, default=ROOT / ".godot/release-tools/windows_release_x86_64.exe")
    args = parser.parse_args()
    engine, template = args.godot.resolve(), args.template.resolve()
    if not engine.is_file() or not template.is_file():
        raise RuntimeError("Godot editor or matching Windows release template is missing")
    # Keep export settings/cache in the workspace instead of changing the user's editor settings.
    portable_dir = ROOT / ".godot/release-tools/editor"
    portable_dir.mkdir(parents=True, exist_ok=True)
    portable_engine = portable_dir / "Godot.exe"
    if not portable_engine.exists() or portable_engine.stat().st_size != engine.stat().st_size:
        shutil.copy2(engine, portable_engine)
    (portable_dir / "_sc_").write_text("", encoding="ascii")
    engine = portable_engine
    build, dist = ROOT / "build", ROOT / "dist"
    for directory in [build, dist]:
        directory.mkdir(exist_ok=True)
        (directory / ".gdignore").write_text("", encoding="utf-8")
    stage = build / "windows-stage"
    reset_generated(stage, build)
    for folder in ["assets", "autoload", "scenes", "scripts", "resources", "licenses"]:
        shutil.copytree(ROOT / folder, stage / folder)
    (stage / "project.godot").write_text(release_project((ROOT / "project.godot").read_text(encoding="utf-8")), encoding="utf-8")
    preset = (ROOT / "tools/windows_export_presets.cfg").read_text(encoding="utf-8").replace("@TEMPLATE@", template.as_posix())
    (stage / "export_presets.cfg").write_text(preset, encoding="utf-8")
    if (stage / "addons").exists() or "_mcp_game_helper" in (stage / "project.godot").read_text():
        raise RuntimeError("Development helpers unexpectedly present in release stage")
    output = dist / PACKAGE
    reset_generated(output, dist)
    run([str(engine), "--headless", "--editor", "--path", str(stage), "--import"], build / "windows-import.log")
    exe = output / "LastLight.exe"
    run([str(engine), "--headless", "--path", str(stage), "--export-release", "Windows Desktop", str(exe)], build / "windows-export.log")
    if not exe.is_file() or exe.stat().st_size < 1_000_000:
        raise RuntimeError("Export did not produce a valid-sized executable")
    if list(output.glob("*.pck")):
        raise RuntimeError("Expected embedded PCK, found a sidecar data file")
    readme = f"""LAST LIGHT {VERSION} - Windows x64

Cara menjalankan:
1. Extract ZIP ini ke folder biasa.
2. Klik dua kali LastLight.exe. Tidak perlu memasang Godot.

Tujuan: bertahan hidup sampai fajar (10 menit). Boss muncul sekitar menit 8.
Serangan berjalan otomatis. Kumpulkan Light Shards berwarna emas untuk naik level.

Kontrol:
- WASD / tombol panah: bergerak.
- Klik kartu atau 1 / 2 / 3: memilih upgrade.
- Escape: pause / resume.
- Volume: menu utama atau menu pause.

Target: Windows 10/11 64-bit dengan driver grafis OpenGL 3.3.
Data game sudah tertanam di LastLight.exe; file .pck terpisah tidak diperlukan.
Progres direset saat memulai run baru. Hasil terakhir dan volume berlaku selama sesi.

Jika menemukan bug, kirim screenshot dan langkah untuk mengulanginya ke pembuat game.
Lisensi engine dan komponen pihak ketiga tersedia di Credits & Licenses dalam game
serta GODOT_LICENSE.txt dan GODOT_COPYRIGHT.txt yang menyertai paket ini.
"""
    (output / "BACA_DULU.txt").write_text(readme, encoding="utf-8")
    for name in ["GODOT_LICENSE.txt", "GODOT_COPYRIGHT.txt"]:
        shutil.copy2(ROOT / "licenses" / name, output / name)
    sha = hashlib.sha256(exe.read_bytes()).hexdigest()
    (output / "SHA256.txt").write_text(f"{sha}  LastLight.exe\n", encoding="ascii")
    archive = dist / (PACKAGE + ".zip")
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as package:
        for file in sorted(output.iterdir()):
            if file.is_file():
                package.write(file, PACKAGE + "/" + file.name)
    archive_sha = hashlib.sha256(archive.read_bytes()).hexdigest()
    (dist / (PACKAGE + ".zip.sha256")).write_text(f"{archive_sha}  {archive.name}\n", encoding="ascii")
    manifest = {"version": VERSION, "renderer": "gl_compatibility", "architecture": "x86_64", "embedded_pck": True, "exe_bytes": exe.stat().st_size, "exe_sha256": sha, "zip_bytes": archive.stat().st_size, "zip_sha256": archive_sha, "runtime_roots": ["assets", "autoload", "scenes", "scripts", "resources", "licenses"]}
    (build / "release-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print("RELEASE:", archive, flush=True)
    print("EXE:", exe, flush=True)


if __name__ == "__main__":
    main()
