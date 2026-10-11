# Lighting engine: how the game lights the world, and the rewrite plan

Status: research done, Phase 0 (instrumentation) in progress on branch `lighting-engine`.

## Summary

Axis & Allies (2004) lights the world with the Direct3D 9 **fixed-function pipeline, per vertex**:
one directional sun, one flat ambient term, no specular on units, no pixel shaders at all. Nothing
is baked (no lightmaps). The only shaders the game ships are three tiny `vs_1_1` vertex shaders,
and their paths are engine settings (AVars).

Data changes (the `Lighting` slice relights the `SUN` entry of every map) can only move numbers
around inside that model. Per-pixel lighting, tone mapping and shadow maps need our own pixel
shaders, and without the source code the only place to add them is the Direct3D 9 call stream.
The plan is therefore a **Direct3D 9 proxy DLL** ("AALight") between AA.exe and dgVoodoo2 that
replaces the fixed-function draws with HLSL shaders.

## How the renderer works

| Part | What the game does |
| --- | --- |
| Engine | Gamebryo 10.1 (`NiDX9Renderer`) with TimeGate's `KKC_` layer on top |
| Direct3D | Loads `D3D9.DLL` at run time (no import-table entry) and calls `Direct3DCreate9`; D3DX9 (shader assembler/compiler 4.09.00.1126) is linked into AA.exe |
| Lights | One `NiDirectionalLight` (the sun) through the fixed-function `SetLight`/`LightEnable`; `NiPointLight` / `NiSpotLight` exist (searchlights, effects) |
| Sun values | The map's `.rmp` `SUN` entry: direction (0.408, 0.408, -0.816) on every shipped map, diffuse 1.0, ambient 0.8 (1.0 on two maps), specular. The `Sun/*.tgi` presets (dusk, night, desert, ...) are not used |
| Terrain | Lit at run time from the height map; AVars `TerrainAmbient 0.15`, `TerrainDiffuse 1`, `TerrainSpecular 15%`; no lightmap entry in any map |
| Static models | Fixed-function lighting (no vertex or pixel shader) |
| Skinned units | `shaders/skin.vso` (vs_1_1): per-vertex Lambert into `oD0`, fixed-function texture stages after it |
| Shadows | `RenderLODShadows`: 0 none, 1 texture blob, 2 projected texture, 3 stencil volumes (`shaders/extrude.vso`, default); shadow colour = `DynamicShadowSunModulate` 0.4 x sun colour |
| Pause | `SunDimmerMultiplierWhenPaused 0.8`, `SunScaleDimmer 0.25` dim the sun |
| Render buckets (names in AA.exe; draw order to be confirmed in Phase 0) | Terrain, terrain replacement objects, terrain decals, non-skinned (grouped by vertex and texture buffer), skinned, node-based things, stencil shadows, water, alpha-blended things, particles, NiLines, floating UI VFX, world and UI catch-alls |

### The unit lighting model, line by line

`skin.vso` disassembled (`dev/vso_dis.py`), after two-bone skinning into `r5` (position) and `r6`
(normal):

```
m4x4 oPos, r5, c0            ; c0-c3 ViewProjTranspose
nrm  r6                      ; dp3 / rsq / mul
mul  r1, c7, c10             ; LightAmbient * MaterialAmbient
dp3  r0, r6, -c5             ; N . L          (c5 LightDirection)
slt/mul                      ; max(0, N . L)
mul  r0, r0, c6              ; * LightDiffuse
mul  r2, r0, c9              ; * MaterialDiffuse
add  oD0, c12 + r1 + r2      ; + MaterialEmissive; the hardware clamps oD0 to 1
```

With the shipped values (ambient 0.8, sun 1.0, white materials) every vertex with N . L above
0.25 reaches 1.0 and clips: that is the flat look. There is no specular term, no rim, no
hemisphere, and lighting is interpolated between vertices.

Constant registers in use: `c0-c3` view-projection, `c5` light direction, `c6` light diffuse, `c7`
light ambient, `c9` material diffuse, `c10` material ambient, `c12` material emissive, `c14`
literals, `c15+` bone matrices (3 registers each). The constant names in AA.exe (VA 0x68A110,
listed in reverse order) suggest `c4` CameraPos, `c8` LightSpecular, `c11` MaterialSpecular, `c13`
MaterialPower; Phase 0 confirms this.

`skinnl.vso` is the same skinning with `oD0 = 1` (unlit). `extrude.vso` extrudes back-facing
vertices away from the light (`c91`/`c92` light data, `c4` world, `c8` view-projection, `c12`, `c16`)
for the stencil shadow volumes.

## Evidence

Every claim above can be reproduced with the tools in `dev/` (Python 3 with capstone for the
code scans):

1. **Engine and renderer.** `python dev/aa_re.py AA.exe str "Gamebryo File Format|NiDX9Renderer::Create|NiDirectionalLight|NiPointLight|NiSpotLight"`
   finds `Gamebryo File Format, Version 10.1.0.0` and the `NiDX9Renderer` messages.
2. **Render buckets.** `python dev/aa_re.py AA.exe str "Catch-all|Stencil Shadows|Non-skinned|Terrain Decals"`
   (string table at VA 0x6883E0).
3. **Fixed-function lighting.** `python dev/d3d9_calls.py AA.exe` lists `IDirect3DDevice9` calls
   by vtable offset. The Gamebryo light manager calls `SetLight(device, index, &light)` at VA
   0x8D4D62 and `LightEnable(device, index, TRUE)` at 0x8D4D74; the renderer resets the pixel
   shader to NULL (fixed-function) at 0x8D70B7 and sets `D3DRS_LIGHTING`, `SPECULARENABLE`,
   `DIFFUSEMATERIALSOURCE` at 0x740F19, 0x740DD7, 0x7E6C76. Check a site with
   `python dev/aa_re.py AA.exe dis 0x8D4D41 20`.
4. **No Direct3D import.** AA.exe's import table has no `d3d9.dll` entry; the strings `D3D9.DLL`
   and `Direct3DCreate9` (VA 0x6B9F94) are used with `LoadLibrary`/`GetProcAddress`.
5. **Only three shaders, all vertex shaders.** `Data.rwd` holds `Shaders/extrude.vso`,
   `Shaders/skin.vso`, `Shaders/skinnl.vso` and no pixel shader. Extract them with
   `dev/rwd.ps1 -Archive Data.rwd -OutDir x -Filter '^Shaders/'` and read them with
   `python dev/vso_dis.py x/Shaders/*.vso`.
6. **Shader paths are settings.** `data/AVars.tgi`: `StencilShaderFilename`, `HWSkinningShader`,
   `HWSkinningNoLightShader`; `UVars.tgi`: `RendererUseHWSkinningShader = true`.
7. **Light data.** `Templates/template_sun.tgi` defines the Sun template; the six `Sun/*.tgi`
   presets are never referenced by a map. Each `.rmp` (TGCK v2) holds MAP, MAP_HEADER, GWORLD,
   RULES, TERRAIN, HEIGHT_MAP, MOUNTAIN_HEIGHT_MAP, ..., SUN, UPDATABLES, MISC_DATA, MAPSTRINGS:
   no lightmap. `SUN` layout is in `src/Features/Lighting/Lighting.ps1`.

## What can and cannot be changed without the proxy

| Change | Without proxy |
| --- | --- |
| Sun and ambient colours, per map | Yes (`Lighting` slice) |
| Sun direction | Yes (same `SUN` entry), untested |
| Unit lighting formula | Partly: a new `skin.vso` through `HWSkinningShader`, vertex stage only, no specular per pixel (a `vs_3_0` shader needs a `ps_3_0` pixel shader) |
| Terrain and building lighting formula | No (fixed-function) |
| Per-pixel lighting, specular, tone mapping, shadow maps | No |

## Plan: the AALight Direct3D 9 proxy

AALight is a 32-bit `D3D9.dll` (C++, HLSL) next to AA.exe. It exports `Direct3DCreate9`, loads
dgVoodoo2's `D3D9.dll` under another name, and wraps `IDirect3D9` and `IDirect3DDevice9`. The rest
of the stack stays: dgVoodoo2 (Direct3D 11), then ReShade (`dxgi.dll`).

```
AA.exe -> D3D9.dll (AALight) -> dgVoodoo D3D9 -> Direct3D 11 -> ReShade dxgi.dll -> GPU
```

| Phase | Work | Done when |
| --- | --- | --- |
| 0. Instrument | Pass-through proxy. On a hotkey, log one frame: every draw with its render bucket guess, `SetLight` / `SetMaterial` values, lighting and fog render states, texture-stage setup, FVF / vertex declaration, shader (by hash) and the constants it gets. Confirm the constant register map. | The game runs unchanged through the proxy; a frame log lists every fixed-function permutation the game uses |
| 1. Matching replacement | One HLSL `vs_3_0` / `ps_3_0` pair per permutation that reproduces the fixed-function result, plus a replacement for `skin.vso` (recognised by bytecode hash) | Screenshots identical to the original |
| 2. New lighting model | Per-pixel, linear-space lighting; wrapped diffuse instead of the hard N . L cut-off; sky/ground hemisphere ambient instead of flat 0.8; Blinn-Phong specular from the material and `TerrainSpecular`; 16-bit float scene target and ACES tone mapping, resolved before the UI (first screen-space draw) | Sunlit units no longer clip; HUD unchanged |
| 3. Sun shadow maps | `RenderLODShadows` 0; record the opaque draws, render a depth map from the sun (previous frame's draws) and sample it with PCF | Soft shadows on terrain and units; the projected-shadow black boxes are gone |
| 4. Local lights | The game's point and spot lights (searchlights, `Effects/SpotLights/*.nif`, muzzle flashes) as per-pixel lights without the 8-light limit | Night maps read as night |
| 5. Ship | `AALight.ini` (biome presets, map to `Sun/*.tgi` preset, matching mode / enhanced toggle); a `LightingEngine` installer slice that downloads the DLL from this repo's releases, like dgVoodoo2 | `install.ps1` installs it, `uninstall.ps1` restores the original |

Risks:

- **dgVoodoo2 under another name**: tested before anything else (Phase 0 smoke test).
- **Objects that hand back the real device** (`GetDevice` on textures and swap chains) bypass the
  wrapper; Phase 0 logs whether the game ever calls them.
- **Dynamic vertex buffers** in the Phase 3 replay: particles are not shadow casters; units use
  static buffers plus bone constants, which the replay copies.
- **In-game testing is manual**: the retail build has no usable console and synthetic input is
  unsafe, so each phase ends with the player checking screenshots.

Alternative kept as a fallback: fork DXVK, which already emulates the fixed-function pipeline in
`d3d9_fixed_function.cpp`, and change its lighting there. It would move the game from Direct3D 11
to Vulkan, and shadow maps are much harder inside DXVK.
