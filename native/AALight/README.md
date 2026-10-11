# AALight

A Direct3D 9 proxy (`D3D9.dll`, 32-bit) that sits between AA.exe and dgVoodoo2 to replace the
game's fixed-function lighting. Design, evidence and phases: [docs/lighting-engine.md](../../docs/lighting-engine.md).

Current state: **Phase 0**. AALight passes every call through unchanged, tracks the device state
and captures frames for analysis.

## Build and test

```bat
native\AALight\build.cmd
```

Needs Visual Studio 2022 or later with the x86 C++ tools and a Windows SDK. The output goes to
`native\AALight\build\` (not committed): `D3D9.dll` and `SmokeTest.exe`.

`SmokeTest.exe <folder>` loads `<folder>\D3D9.dll` (AALight, with `D3D9.dgVoodoo.dll`,
`dgVoodoo.conf` and an `AALight.ini` with `CaptureFrame=3` beside it), draws a lit triangle and a
screen-space quad, checks both colours and leaves a capture in `<folder>\AALight\`.

## Try it in the game

```powershell
powershell -ExecutionPolicy Bypass -File native\AALight\deploy.ps1 -GameDir "C:\Games\Axis & Allies"
powershell -ExecutionPolicy Bypass -File native\AALight\deploy.ps1 -GameDir "C:\Games\Axis & Allies" -Remove
```

Then play: AALight captures one frame by itself after about 300 battle frames, and
**Ctrl+Shift+F11** captures the next frame at any time. Output in the game folder:

| File | Contents |
| --- | --- |
| `AALight.log` | Device and caps, shaders created, every light change |
| `AALight\capture-<time>\frame.log` | Every state change and draw of the frame, in order |
| `AALight\capture-<time>\permutations.log` | The distinct pipeline setups, with draw counts: the work list for Phase 1 |
| `AALight\capture-<time>\scene.tga`, `frame.tga` | The 3D scene before the first UI draw, and the finished frame |
| `AALight\capture-<time>\vs_<hash>.vso` | Vertex shaders the frame used (`python dev/vso_dis.py` reads them) |

## Source

| File | Role |
| --- | --- |
| `src/Proxy.cpp`, `src/AALight.def` | Exports (`Direct3DCreate9` and pass-throughs), loads the real Direct3D 9 |
| `src/Direct3D9.*` | `IDirect3D9` wrapper: hands out AALight devices |
| `src/Device.*` | `IDirect3DDevice9` wrapper: state tracking, capture triggers |
| `src/Capture.*` | Frame capture files |
| `src/Forward.h` | Generated pass-through of every method (`tools/gen_forward.py` from the SDK `d3d9.h`) |
| `src/Names.*`, `src/Common.*` | Enum names; config, log, hash |
