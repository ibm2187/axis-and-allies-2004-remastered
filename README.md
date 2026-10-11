# Axis & Allies (2004) Remastered

A fan remaster of TimeGate's *Axis & Allies* real-time strategy game (2004, v1.0.5.0) for current
Windows PCs and screens up to 4K:

- **Runs on Windows 10 and 11**: font crash fixed, Direct3D 11 through dgVoodoo2, 4 GB of memory for the game.
- **Widescreen UI** at your monitor's native resolution, with nothing stretched, and text that stays
  the right size at any Windows display scaling.
- **HD art**: AI-upscaled UI art and about 4,000 unit, building, terrain and world-map textures.
- **Better visuals**: relit maps, higher-quality shadows and terrain, more particles, a wider camera zoom range.

No game files are included: you need your own copy of the game.

## Install

1. **Download** this mod and unzip it anywhere (next to the game folder is easiest).
2. **Double-click `Install.cmd`.** It finds the game (or asks you to pick its folder), detects your
   screen and asks whether to install the HD art. That's all.
3. **Play**: start `AA.exe` as usual.

If Windows shows "Windows protected your PC", click **More info > Run anyway** (the installer is a
plain script and isn't signed).

**Requirements:** Windows 10 (version 1803 or later) or Windows 11, a DirectX 11 graphics card, the
game at version 1.0.5.0 (the installer checks it and changes nothing on other versions), and an
internet connection while installing. The installer downloads dgVoodoo2 and Liberation Sans from
their official releases, and the HD art pack if you choose it.

## Uninstall

Double-click `Uninstall.cmd`. It removes every file the mod added, restores `AA.exe` byte for byte,
removes the compatibility flag and puts your previous game resolution back.

## Questions

- **New monitor or resolution?** Run `Install.cmd` again. It's safe to run any number of times.
- **Playing over LAN?** Every PC needs the mod at the same version: the relit maps have different
  checksums from the originals.
- **Where is the log?** In `logs\` inside the mod folder (one file per install or uninstall).
- **Did it change my saves or settings?** Saves, no. Settings: only the screen resolution in
  `Documents\A&A\data\User\UVars.tgi` (the uninstaller restores it).
- **Advanced options** (PowerShell, from the mod folder):

  ```powershell
  powershell -ExecutionPolicy Bypass -File install.ps1 -GameDir "C:\Games\Axis & Allies" -Resolution 2560x1440
  ```

  | Option | Effect |
  | --- | --- |
  | `-GameDir <folder>` | Game folder (the one with `AA.exe`); found automatically if left out |
  | `-Resolution WxH` | Set up for this screen mode instead of the monitor's native one |
  | `-NoHdArt` | Skip (or remove) the HD art |
  | `-HdPackDir <folder>` | Where the HD pack zips are, if not next to `Install.cmd` |
  | `-Supersample 2x` | Render at twice the resolution and downsample: smoother edges, but the mouse feels slower at 4K |

## What it changes

| Feature | What | Files |
| --- | --- | --- |
| Compatibility | 4 GB large-address-aware flag; DPI-aware flag so Windows doesn't scale the game | `AA.exe` byte 0x946; `HKCU\...\AppCompatFlags\Layers` |
| Renderer | dgVoodoo2 2.87.5: Direct3D 9 to 11, 16x anisotropic filtering, v-sync, no watermark; adds the largest 4:3 mode (2880x2160 on 4K) to the list | `D3D9.dll`, `dgVoodoo.conf`, `dgVoodooCpl.exe` |
| Fonts | Crash fix: drops the Korean GulimChe sets, replaces Arial with Liberation Sans Bold. GDI+ fonts in pixels instead of points (text size independent of display scaling; sizes x4/3) | `data/Fonts/`; `AA.exe` bytes 0x3089CF |
| HD art | Prebuilt AI-upscaled UI art (the set for your screen height), fixed-path icons, 3D and terrain textures, 2x cursor at 2160p | `data/**`, `skins/<nation>/**` |
| Widescreen | Virtual UI width = 768 x aspect; menus, HUD, dialogs and campaign map moved instead of stretched; control panel art sliced | `data/AVars.tgi`, `data/UI/**`, `data/MetaGame/UI/**`, `skins/<nation>/UI/**` |
| Graphics | Terrain pool 1024 px, larger shadow and general pools, terrain specular, hit animations, 1.5x particles, deeper shadows (`ViewQualityExtreme` stays off: it drew infantry shadows as black boxes) | `data/UVars.tgi`, `data/AVars.tgi` |
| Lighting | Maps relit: ambient 0.8 -> 0.55 (slightly cool), slightly warm sun | `data/Maps/**/*.RMP` (only the `SUN` entry differs) |
| Camera | Zoom range 0.7-1.4 -> 0.5-1.8; terrain pool 200 entries to match | `AA.exe` bytes 0x23C5, 0x2447; `data/AVars.tgi`, `data/UVars.tgi` |
| Display | Game resolution = monitor's native resolution | `Documents\A&A\data\User\UVars.tgi` |

Loose files under `data/` override the same paths inside `Data.rwd`, so the game's archives are
never modified. Every file the mod writes is listed in `<game>\Remastered\<Feature>.files`.

## Optional: ReShade

ReShade 6.8 (32-bit) works on top of dgVoodoo. In its installer pick **Direct3D 10/11/12** (it
becomes `dxgi.dll`; choosing Direct3D 9 would overwrite dgVoodoo's `D3D9.dll`). Working settings
are in `src/Features/ReShade/`: copy `ReShade.ini` and `ReShadePreset.ini` next to `AA.exe` while
the game is closed (ReShade saves over them on exit).

- Depth (Add-ons > Generic Depth): the 3840x2160 D24S8 buffer with "Copy depth buffer before clear
  operations" on (`[DEPTH] DepthCopyBeforeClears=1`); without it ReShade only sees the HUD's depth.
- `RESHADE_DEPTH_LINEARIZATION_FAR_PLANE=50` (the default 1000 renders the whole RTS scene as near-black depth).
- Packages: Standard effects, SweetFX, qUINT, iMMERSE. Effect order: UIMask_Top, iMMERSE MXAO (High,
  radius 2.0, amount 0.9, fade 1.0), Lightroom (contrast +0.12, vibrance +0.20, saturation +0.05),
  iMMERSE Sharpen 0.5, iMMERSE SMAA, UIMask_Bottom.
- HUD mask: `python src/Features/ReShade/reshade_uimask.py <game dir> "<game dir>/reshade-shaders/Textures/UIMask.png"`
  (needs Pillow and numpy) builds it from the control panel art of all nation skins; white = HUD,
  which UIMask restores so grading and sharpening only touch the 3D scene.

## For developers

### Layout

The code is organized by feature. Each folder in `src/Features/` is one vertical slice with an
`Install-<Feature>` and `Uninstall-<Feature>` function and everything that feature needs (data,
configs, build scripts).

```
Install.cmd, Uninstall.cmd     double-click entry points (run install.ps1 / uninstall.ps1 -Wizard)
install.ps1, uninstall.ps1     command-line entry points
src/Remastered.psm1            loads everything below
src/Installer/                 order of the features, wizard prompts, context, earlier-install cleanup
src/Features/<Feature>/        Compatibility, Renderer, Fonts, HdArt, Widescreen, Graphics, Lighting,
                               Camera, Display (+ ReShade extras, not installed)
src/Shared/                    TGCK archive reader, zlib/TGA, tracked game files, engine settings
                               files, AA.exe byte patches, downloads, game folder discovery
dev/                           reverse-engineering tools (Python/PowerShell, maintainer only)
```

The installer only uses Windows PowerShell 5.1. Python is needed only to build the HD pack and for
the tools in `dev/`.

### Building the HD pack

`src/Features/HdArt/HdArt.Build.ps1` makes the pack on the maintainer's PC from their own game
files. It needs Python 3 on `PATH` (Pillow and numpy go into `.cache\venv`) and a Vulkan GPU:

```powershell
Import-Module .\src\Remastered.psm1 -DisableNameChecking
Build-HdPack -GameDir "C:\Games\Axis & Allies" -Version 1.0
```

It writes the zip parts to `.cache\hdpack\parts\` (upload them as release assets under the tag
`hd-<version>`) and `src\Features\HdArt\hdpack.json` (commit it). Real-ESRGAN results are cached in
`.cache`, so after the first build (about an hour) a rebuild takes minutes. The generated art is
never committed: it is derived from the game's art and the texture models are CC BY-NC-SA 4.0.

**UI art.** Textures are referenced as `/UI/%s/...`; `AA.exe` fills `%s` with the screen width and
falls back to the base art (made for 1024x768) when that folder is missing. The 800 and 1280 sets
are the base art rescaled by width/1024. `build/upscale_ui.py` builds a set the same way: base size
x screenH/768, rounded up to powers of two (the engine stretches every texture to that on load),
from the 1280 art where it exists, through Real-ESRGAN `realesrgan-x4plus` (RGB and alpha
separately) and Lanczos. Icons the game loads by a fixed path are replaced in place. PNGs are
written as a single `IDAT` chunk (the game's loader reads only the first). Command-grid frames,
minimap icons, unit banners and nation badges keep their shipped size (`FIXED_SIZE`): the game
draws them pixel for pixel.

**Textures.** `build/upscale_textures.py` upscales the DDS textures of units, buildings, doodads,
terrain, roads, effects and the campaign world map, and the 409 TGA ground tiles. Colour goes
through Real-ESRGAN with texture-trained models: **UltraMix Balanced** for terrain and roads,
**UltraSharp** for everything else (compared against realesrgan-x4plus, Remacri, NMKD Siax and
Nomos8kSC). Alpha is Lanczos-resized and binary masks re-thresholded. Each texture is re-encoded by
DirectXTex `texconv` to its original format (DXT1/3/5) with a full mipmap chain. Ground tiles are
upscaled as a 3x3 wrap so they still tile, and the fine grain the model smooths away is blended
back in.

| Art | Factor | Cap |
| --- | --- | --- |
| Units, buildings, campaign world map, doodads, shared models, roads, bridges, flares, special ops | 4x | 1024 px (world map 2048) |
| Terrain ground tiles and water frames | 4x | 512 px |
| Effects, trailers, generals, cutscene | 2x | 512-2048 px |

### Engine notes

- 32-bit, Direct3D 9 via Gamebryo; settings in `UVars.tgi` / `AVars.tgi`; user settings in `Documents/A&A/data/User/UVars.tgi`.
- `.rwd` = TGCK archive, uncompressed; directory at the end, entry offsets relative to the Files
  section (byte 30). `.rmp` maps are TGCK v2 with zlib entries and 96-byte directory records.
- Fonts: size = `size * screenH / InterfacePositioningHeight`, created with GDI+ in points, so at
  150% Windows scaling glyphs came out 1.5x larger than their cells.
- Every map embeds its own light (`SUN` entry); the `Sun/*.tgi` presets are not used.
- The gameplay zoom limits are vars registered with flag 2 (not overridable from `AVars.tgi`).
- UI art: transparency is on/off (any alpha above 0 draws opaque). `ViewQualityExtreme` switches texture shadows to projected ones, which render as solid black boxes under dgVoodoo.
- The terrain texture pool must be 1024 px or the HD ground tiles don't show; forced MSAA in
  dgVoodoo draws seams on terrain patches; dgVoodoo VRAM must stay at 2048 MB or the engine
  computes negative free memory.

## Credits and licences

The mod's code and documentation are under the [MIT License](LICENSE). The HD art pack is not: it
is derived from the game's own art and made with CC BY-NC-SA 4.0 models, so it is for
non-commercial use only and you need your own copy of the game.

- [dgVoodoo2](https://github.com/dege-diosg/dgVoodoo2) by Dege (freeware), downloaded at install time.
- [Liberation Sans](https://github.com/liberationfonts/liberation-fonts) (SIL Open Font License 1.1), downloaded at install time.
- HD art made with [Real-ESRGAN ncnn-vulkan](https://github.com/xinntao/Real-ESRGAN) (BSD-3-Clause),
  the UltraSharp and UltraMix Balanced models as packaged by [Upscayl](https://github.com/upscayl/upscayl)
  (CC BY-NC-SA 4.0: the HD pack is for non-commercial use), and
  [DirectXTex texconv](https://github.com/microsoft/DirectXTex) (MIT).

*Axis & Allies* is a trademark of Hasbro. The 2004 game was developed by TimeGate Studios and
published by Atari. This project is not affiliated with or endorsed by any of them.
