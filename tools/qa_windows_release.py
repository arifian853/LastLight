"""Validate the embedded distribution data and launch the actual Windows binary."""
import argparse
import ctypes
from ctypes import wintypes
import hashlib
import json
from pathlib import Path
import re
import shutil
import struct
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]


def execute(command, cwd, log, expected=None):
    result = subprocess.run(command, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, encoding="utf-8", errors="replace", timeout=180)
    log.write_text(result.stdout, encoding="utf-8")
    for line in result.stdout.splitlines():
        if any(key in line for key in ["checks,", "CHECKPOINT", "RESULT", "SCRIPT ERROR", "FAIL:"]):
            print(line, flush=True)
    if result.returncode or "SCRIPT ERROR:" in result.stdout or "FAIL:" in result.stdout or (expected and expected not in result.stdout):
        raise RuntimeError(f"QA failed: {log}")
    return result.stdout


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--exe", type=Path, required=True)
    parser.add_argument("--godot", type=Path, default=ROOT / ".godot/release-tools/editor/Godot.exe")
    parser.add_argument("--visual", action="store_true")
    parser.add_argument("--visual-scene", choices=["menu", "game", "pause"], default="menu")
    parser.add_argument("--skip-pack-tests", action="store_true")
    args = parser.parse_args()
    exe, editor = args.exe.resolve(), args.godot.resolve()
    directory = ROOT / "build/release-qa"
    directory.mkdir(parents=True, exist_ok=True)
    isolated = directory / "empty-working-directory"
    isolated.mkdir(exist_ok=True)
    data = exe.read_bytes()
    pe_offset = struct.unpack_from("<I", data, 0x3C)[0]
    assert data[:2] == b"MZ" and data[pe_offset:pe_offset+4] == b"PE\0\0"
    assert struct.unpack_from("<H", data, pe_offset + 4)[0] == 0x8664, "Expected Windows x64"
    assert data[-4:] == b"GDPC", "Expected an embedded Godot pack"
    assert not list(exe.parent.glob("*.pck")), "Unexpected external PCK"
    print("PE: Windows x64, embedded PCK, no sidecar required", flush=True)
    base = [str(editor), "--headless", "--main-pack", str(exe)]
    scripts = [] if args.skip_pack_tests else ["release_package.gd", "day2_smoke.gd", "day3_smoke.gd", "day4_smoke.gd", "day5_smoke.gd", "day6_smoke.gd", "menu_layout_smoke.gd"]
    for script in scripts:
        log = directory / (script.removesuffix(".gd") + ".log")
        execute(base + ["--log-file", str(log), "--script", str(ROOT / "tests" / script)], isolated, log, "0 failures")
    if scripts:
        print("Exported data suites complete", flush=True)
    if args.visual:
        frames = directory / ("visual-" + hashlib.sha256(data).hexdigest()[:12] + "-" + str(time.time_ns()))
        frames.mkdir(exist_ok=True)
        scene_name = args.visual_scene
        log = directory / ("native-windows-" + scene_name + "-launch.log")
        startup = subprocess.STARTUPINFO()
        startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
        startup.wShowWindow = subprocess.SW_HIDE
        command = [str(exe), "--resolution", "1280x720", "--write-movie", str(frames / (scene_name + ".png")), "--fixed-fps", "30", "--quit-after", "300", "--log-file", str(log)]
        process = subprocess.Popen(command, cwd=isolated, startupinfo=startup, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, encoding="utf-8", errors="replace")
        callback_type = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
        handles = []
        def find_window(handle, _):
            owner = wintypes.DWORD()
            ctypes.windll.user32.GetWindowThreadProcessId(handle, ctypes.byref(owner))
            if owner.value == process.pid:
                title = ctypes.create_unicode_buffer(512)
                ctypes.windll.user32.GetWindowTextW(handle, title, 512)
                if "LastLight" in title.value:
                    handles.append(handle)
            return True
        callback = callback_type(find_window)
        # Ask only this QA process's window to close after it has rendered the menu.
        deadline = time.monotonic() + 30.0
        started_game = False
        paused_game = False
        restored_window = False
        while process.poll() is None and time.monotonic() < deadline:
            if (frames / (scene_name + "00000024.png")).exists():
                handles.clear()
                ctypes.windll.user32.EnumWindows(callback, 0)
                if handles:
                    ctypes.windll.user32.PostMessageW.argtypes = [wintypes.HWND, wintypes.UINT, wintypes.WPARAM, wintypes.LPARAM]
                    handle = handles[0]
                    if scene_name in ["game", "pause"] and not started_game:
                        # Activate the focused Start button through the real Windows input path.
                        ctypes.windll.user32.ShowWindow(handle, 5)
                        ctypes.windll.user32.SetForegroundWindow(handle)
                        ctypes.windll.user32.PostMessageW(handle, 0x0007, 0, 0)
                        ctypes.windll.user32.PostMessageW(handle, 0x0100, 0x0D, 1 | (0x1C << 16))
                        time.sleep(0.06)
                        ctypes.windll.user32.PostMessageW(handle, 0x0101, 0x0D, 1 | (0x1C << 16) | 0xC0000000)
                        started_game = True
                    if scene_name == "pause" and started_game:
                        if not paused_game and (frames / (scene_name + "00000060.png")).exists():
                            # Reproduce Escape after maximizing the actual release window.
                            ctypes.windll.user32.ShowWindow(handle, 3)
                            ctypes.windll.user32.PostMessageW(handle, 0x0100, 0x1B, 1 | (0x01 << 16))
                            time.sleep(0.06)
                            ctypes.windll.user32.PostMessageW(handle, 0x0101, 0x1B, 1 | (0x01 << 16) | 0xC0000000)
                            paused_game = True
                        if not restored_window and (frames / (scene_name + "00000105.png")).exists():
                            shutil.copy2(frames / (scene_name + "00000105.png"), directory / "native-pause-maximized.png")
                            ctypes.windll.user32.ShowWindow(handle, 9)
                            restored_window = True
                    last_frame = 155 if scene_name in ["game", "pause"] else 24
                    if (frames / (scene_name + f"{last_frame:08d}.png")).exists():
                        ctypes.windll.user32.PostMessageW(handle, 0x0010, 0, 0)
                        break
            time.sleep(0.05)
        stdout, _ = process.communicate(timeout=60)
        log.write_text(stdout, encoding="utf-8")
        images = sorted(frames.glob(scene_name + "*.png"))
        if process.returncode or not images or "SCRIPT ERROR:" in stdout or "ObjectDB" in stdout:
            raise RuntimeError(f"Native Windows rendering failed; see {log}")
        shutil.copy2(images[-1], directory / ("native-" + scene_name + ".png"))
        print("Actual release binary rendered:", directory / ("native-" + scene_name + ".png"), flush=True)
        if scene_name == "pause":
            # Capture both overlays from the same embedded pack without Movie Maker's fixed frame size.
            execute([str(editor), "--main-pack", str(exe), "--script", str(ROOT / "tests/menu_layout_smoke.gd"), "--", "--capture-dir=" + str(directory)], isolated, directory / "menu-layout-rendered.log", "0 failures")
    if not args.skip_pack_tests:
        (directory / "result.json").write_text(json.dumps({"exe": exe.name, "exe_sha256": hashlib.sha256(data).hexdigest(), "architecture": "x86_64", "embedded_pck": True, "pack_suites_passed": len(scripts), "native_visual_requested": args.visual}, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
