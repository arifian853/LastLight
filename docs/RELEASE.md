# LAST LIGHT — Windows release 0.1.2

Share `dist/LastLight-0.1.2-Windows-x64.zip` (38,203,898 bytes, about 38 MB).
Extract it and run `LastLight.exe`. The executable is self-contained: its game data and engine notices are embedded, and it requires neither Godot nor a separate PCK file.

The package includes Indonesian instructions, engine/third-party notices, and the executable's SHA-256. It targets Windows 10/11 x64 with an OpenGL 3.3 graphics driver. The build is unsigned. Credits & Licenses in the main menu also exposes the notices when distributing the executable alone.

## Fixed in 0.1.2

Upgrade selection, Escape pause, and run results now cover the viewport and center their content in the exported game. Their root Controls previously lacked an explicit anchor layout mode: the editor displayed full-screen anchors correctly, but the exported overlays became zero-sized and centered their children at the upper-left corner.

The fix sets `layout_mode = 1` explicitly on all three overlay scene roots. The regression test reproduces the original problem against the embedded 0.1.1 pack (75/75 initial checks fail) and passes against 0.1.2. Test exported data when changing UI; source-scene checks alone missed this issue.

## Rebuild

Requirements: Python 3.10+ and the standard Godot 4.7.2 stable Windows editor.

```powershell
python tools/fetch_windows_template.py
python tools/build_windows.py --godot "D:\path\to\Godot_v4.7.2-stable_win64.exe"
python tools/qa_windows_release.py --exe dist/LastLight-0.1.2-Windows-x64/LastLight.exe --visual --visual-scene pause
```

The template fetcher uses HTTP byte ranges to extract only the matching Windows executable from the official Godot release archive. It validates ZIP CRC and records the download source and extracted template SHA-256 in `.godot/release-tools/provenance.json`.

The builder creates a portable editor cache under `.godot/release-tools/editor/` and a clean project under `build/windows-stage/`. It copies runtime assets, scenes, scripts, upgrades, autoload data, and licenses, removes the MCP helper/editor plugin settings, selects Compatibility rendering, and exports an x64 release with embedded PCK. The development project retains its MCP configuration and renderer settings.

Generated folders `build/` and `dist/` are excluded from Git and Godot's editor scan. Build logs, release manifest, QA results, and native screenshots live under `build/`.

## Validation of this release

- PE architecture is x64; an embedded Godot PCK is present; no sidecar PCK is required.
- Twenty package checks verify version, renderer, runtime scenes/resources, ten upgrades, embedded licenses, and absence of MCP, tests, and build tools.
- All 495 gameplay regression checks pass against the embedded exported data, using the matching editor runtime with `--main-pack` from an empty working directory. The production template disables arbitrary script/scene-path overrides, so the test runner remains outside the distributed executable.
- Another 93 menu layout checks pass: centered content, visible cards, full-screen dim backgrounds, and resizing while pause/upgrade menus are open. The six window-size cases include 1280×720, the reported 1918×991, 1024×768, 960×540, 2560×1080, and a return to 1280×720.
- Native Windows QA opens the actual release's Start Run button, maximizes its window, opens pause with Escape, restores the window while paused, then closes normally. Screenshots: `build/release-qa/native-pause-maximized.png` and `native-pause.png`. Movie Maker records a fixed 1280×720 frame.
- A separate OpenGL run of the packed data captures both overlays at 1918×991 without Movie Maker's fixed frame size. All 95 checks, including two screenshot saves, pass. Screenshots inspected: `build/release-qa/packed-pause.png` and `packed-upgrade.png`; log: `menu-layout-rendered.log`.
- Two full runs of the earlier 0.1.1 exported data used normal movement, damage, XP, upgrades, and boss logic, without invulnerability or time jumps. These are retained as balance evidence; 0.1.2 changes menu layout only:

| Seed | Outcome | Survival | Level | Kills | HP | Boss defeated |
| --- | --- | --- | --- | --- | --- | --- |
| 7319 | Victory | 10:00 | 27 | 655 | 33.5 / 120 | No |
| 9254 | Victory | 10:00 | 28 | 677 | 72 / 120 | Yes |

- The final ZIP's CRC is valid; the EXE inside the ZIP matches the tested EXE's SHA-256. Final native close tests and gameplay suites report no script failures or resource-leak diagnostics. Sandboxed tools emit a Windows certificate-store startup message; the game uses no network service.

## Checksums

```text
EXE  621664747914da88940500f7d0cb17097d264d49f53a022e0b5ab4a80e3bdfc8
ZIP  32d9539df819607bfe927e837e5a4a0ac16b3db7c4b9becbdc1d55fc60883b65
```

## References

- [Official Godot 4.7.2 release](https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable)
- [Godot Windows export](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_windows.html)
- [Godot system requirements](https://docs.godotengine.org/en/stable/about/system_requirements.html)
- [Self-contained editor mode](https://docs.godotengine.org/en/stable/tutorials/io/data_paths.html#self-contained-mode)
