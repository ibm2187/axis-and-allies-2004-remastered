# Axis & Allies (2004) Modernization

Mod files, tools and an installer that make TimeGate's *Axis & Allies* (2004 RTS, v1.0.5.0, build 4129.7) run well on Windows 11 at 4K. No game files are included; you need your own copy.

Plan and full change log: [modernization plan doc](https://claude.ai/code/artifact/3d00b4da-e290-4bc4-a95a-6d7bdebf5dce)

## Install

```powershell
pwsh -ExecutionPolicy Bypass -File install.ps1 -GameDir "C:\path\to\Game Files"
```

Requires Python 3 on `PATH` (for the `AA.exe` header patch) and internet access (to download dgVoodoo2 and DXVK from their GitHub releases).

## What it changes

| Change | Where | Undo |
| --- | --- | --- |
| Font crash fix: drops Korean GulimChe sets, Arial replaced with Tahoma | `data/Fonts/*.tgi` (loose overrides of `Data.rwd`) | Delete `data/Fonts` |
| dgVoodoo2: D3D9 to D3D11, 16x AF, v-sync, no watermark; adds the largest 4:3 mode for the desktop (2880x2160 on 4K) to the resolution list | `D3D9.dll`, `dgVoodoo.conf`, `dgVoodooCpl.exe` | Delete those files |
| DXVK staged (not active) | `_wrappers/dxvk/d3d9.dll` | Delete `_wrappers` |
| 4 GB large-address-aware flag | `AA.exe` byte 0x946: 0x0E to 0x2E | `python tools/laa.py AA.exe --clear` |
| DPI-aware flag | `HKCU\...\AppCompatFlags\Layers`, value = path of `AA.exe` | Delete that value |

## Recommended resolution

The UI is laid out in a fixed 1024x768 space and stretched to the screen, so 16:9 modes look wide. Until the widescreen patch lands, pick the largest 4:3 mode in Options (2880x2160 on a 4K display); dgVoodoo pillarboxes it with correct proportions.

## Layout

- `mod/` — files copied into the game folder as-is. Loose files under `data/` override the same paths inside `Data.rwd`.
- `tools/` — `rwd.ps1` (list/extract `.rwd` archives), `laa.py`, `strip_hangul.py`, `ttfinfo.py`, `tga2png.py`, `capture_menu.ps1` (launch + screenshot main menu), `peinfo.ps1`, `aa_re.py` (strings/constants/xrefs/disassembly, needs capstone), `memscan.py` (read-only memory scan of a running AA.exe).

## Engine notes

- 32-bit, Direct3D 9 via Gamebryo; settings in `UVars.tgi` / `AVars.tgi`; user settings saved to `Documents/A&A/data/User/UVars.tgi`.
- `.rwd` = TGCK archive, uncompressed; directory at the end, entry offsets relative to the Files section (byte 30).
- Known issue: the engine packs glyph-sheet rows too tightly, clipping the tails of g/j/p/q/y.
