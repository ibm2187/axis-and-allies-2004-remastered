# Changelog

All notable changes to Axis & Allies (2004) Remastered. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow [Semantic Versioning](https://semver.org/).

## [1.0.1] - 2026-10-11

### Fixed
- Coloured noise along the top edge of the HUD panels with the HD art. The game's UI art uses
  on/off transparency and draws any non-zero alpha as opaque; the upscaled art had soft edges
  that showed the padding colours of transparent pixels. UI art with on/off transparency keeps it
  (HD pack 1.1, release `hd-1.1`).

## [1.0.0] - 2026-10-11

The first release meant for other players: one double-click to install, nothing else to set up.

### Added
- `Install.cmd` and `Uninstall.cmd`: double-click installer and uninstaller. They find the game
  folder (or ask with a folder picker), detect the monitor's native resolution, set the game to it,
  ask for administrator rights only when the game folder needs them, and write a log to `logs\`.
- Prebuilt HD art pack: the AI-upscaled UI art and 3D/terrain textures are installed from
  downloadable zip parts (SHA-256 checked) instead of being generated on the player's GPU. UI art
  sets for 1080, 1440 and 2160 screen heights; the nearest one is used and renamed for the
  player's screen width.
- Re-running the installer updates an existing install (or one made by the earlier scripts) in place.
- MIT licence for the code (`LICENSE`); the HD pack keeps its own non-commercial terms.
- Uninstall restores everything: original `AA.exe` bytes, no loose files left behind, the registry
  flag removed and the game resolution the player had before.

### Changed
- No Python needed to install: everything runs in the Windows PowerShell 5.1 that ships with
  Windows 10 and 11. The tools were ported and checked to produce byte-identical files.
- The code is organized by feature (vertical slices in `src/Features/`): Compatibility, Renderer,
  Fonts, HdArt, Widescreen, Graphics, Lighting, Camera and Display, each owning its install and
  uninstall. Shared plumbing is in `src/Shared/`; reverse-engineering tools moved to `dev/`.
- Every feature records the files it writes in `<game>\Remastered\<Feature>.files`.
- DXVK is no longer staged in `_wrappers\` (it was never active).

### Fixed
- The in-game menu layout (`UI/Game/game_menu.tgi`) lost its last lines after the widescreen
  rewrite: the resign dialog's Cancel button layout and the closing braces were missing.

## [0.4.0] - 2026-10-11

### Added
- Map lighting: every map embeds its own light (ambient 0.8 next to a full sun), which lit units
  and buildings flat. Ambient lowered to 0.55 (slightly cool), sun slightly warm.
- Camera zoom range 0.7-1.4 -> 0.5-1.8 (hard-coded in `AA.exe`, patched), with a terrain texture
  pool sized for it (200 entries).
- Terrain specular highlights, hit animations, 1.5x particles, deeper unit shadows.
- Optional supersampling through dgVoodoo (`-Supersample 2x`). Off by default: at 4K it made the
  mouse and camera less responsive.

## [0.3.0] - 2026-10-11

### Added
- 4K UI art set made with Real-ESRGAN (menus, HUD, dialogs, campaign map, icons, nation skins), PNGs
  written as one IDAT chunk because the game's loader only reads the first.
- 3,964 model, building, terrain, road and world-map textures upscaled 4x with texture-trained
  models (UltraSharp, UltraMix Balanced for terrain), ground tiles with their grain restored.
- 2x mouse cursor at 2160p.
- Rendering settings for current hardware: `ViewQualityExtreme`, terrain texture pool 1024 px,
  larger shadow and general pools.
- ReShade preset (iMMERSE MXAO, SMAA, sharpen, Lightroom grading) with a HUD mask.

### Changed
- Command-grid frames, minimap icons, unit banners and nation badges keep their shipped size (the
  game draws them pixel for pixel).
- Forced MSAA off (it drew seams on the terrain); dgVoodoo VRAM kept at 2048 MB.

## [0.2.0] - 2026-10-10

### Added
- Widescreen UI: the virtual layout space is widened to the screen's aspect ratio and the menus,
  HUD, dialogs and campaign map are moved instead of stretched; the control panel art is sliced.
- Liberation Sans Bold (SIL OFL) replaces Arial for the small UI fonts.

### Fixed
- Text grew with Windows display scaling and clipped the tails of g, j, p, q and y: GDI+ fonts are
  created in pixels (`AA.exe` patch) and sizes scaled by 4/3.

## [0.1.0] - 2026-10-10

### Added
- Runs on Windows 11: crash fix for the "Processing non-Unicode TrueType font" abort (GulimChe and
  Arial font sets), 4 GB large-address-aware flag, DPI-aware flag, dgVoodoo2 (Direct3D 9 to 11)
  with 16x anisotropic filtering and the largest 4:3 mode in the resolution list.
- Reverse-engineering tools for the TGCK archives and `AA.exe`.

[1.0.1]: https://github.com/ibm2187/axis-and-allies-2004-remastered/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/ibm2187/axis-and-allies-2004-remastered/compare/48a4bf1...v1.0.0
[0.4.0]: https://github.com/ibm2187/axis-and-allies-2004-remastered/compare/03f919c...48a4bf1
[0.3.0]: https://github.com/ibm2187/axis-and-allies-2004-remastered/compare/85b34cb...03f919c
[0.2.0]: https://github.com/ibm2187/axis-and-allies-2004-remastered/compare/d291b66...85b34cb
[0.1.0]: https://github.com/ibm2187/axis-and-allies-2004-remastered/commit/d291b66
