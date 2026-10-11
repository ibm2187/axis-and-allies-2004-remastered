// AALight's D3D9.dll entry points. AA.exe loads D3D9.DLL at run time and calls Direct3DCreate9;
// this DLL loads the real Direct3D 9 (dgVoodoo2 renamed to D3D9.dgVoodoo.dll by default, see
// AALight.ini) and wraps what it returns.
#include <initguid.h>  // defines the IIDs from d3d9.h in this translation unit

#include "Common.h"
#include "Direct3D9.h"

namespace {

HMODULE realModule = nullptr;

HMODULE RealD3D9() {
  if (realModule) return realModule;
  std::wstring path = GetConfig().realD3D9;
  if (path.size() < 2 || path[1] != L':') path = ModuleDir() + path;
  realModule = LoadLibraryW(path.c_str());
  if (!realModule) {  // fall back to Windows' own Direct3D 9
    Log("cannot load %ls (error %lu), using the system d3d9.dll", path.c_str(), GetLastError());
    wchar_t system[MAX_PATH];
    GetSystemDirectoryW(system, MAX_PATH);
    path = std::wstring(system) + L"\\d3d9.dll";
    realModule = LoadLibraryW(path.c_str());
  }
  Log("real Direct3D 9: %ls (%s)", path.c_str(), realModule ? "loaded" : "FAILED");
  return realModule;
}

template <typename T>
T RealProc(const char* name) {
  HMODULE module = RealD3D9();
  return module ? reinterpret_cast<T>(GetProcAddress(module, name)) : nullptr;
}

}  // namespace

extern "C" {

IDirect3D9* WINAPI AALight_Direct3DCreate9(UINT version) {
  auto create = RealProc<IDirect3D9*(WINAPI*)(UINT)>("Direct3DCreate9");
  IDirect3D9* real = create ? create(version) : nullptr;
  Log("Direct3DCreate9(%u) -> %p", version, real);
  LogFlush();
  return real ? new Direct3D9(real) : nullptr;
}

// Pass-throughs, in case anything asks for them.
HRESULT WINAPI AALight_Direct3DCreate9Ex(UINT version, IDirect3D9Ex** out) {
  Log("Direct3DCreate9Ex called: passed through unwrapped");
  auto create = RealProc<HRESULT(WINAPI*)(UINT, IDirect3D9Ex**)>("Direct3DCreate9Ex");
  return create ? create(version, out) : D3DERR_NOTAVAILABLE;
}

int WINAPI AALight_D3DPERF_BeginEvent(D3DCOLOR color, LPCWSTR name) {
  auto f = RealProc<int(WINAPI*)(D3DCOLOR, LPCWSTR)>("D3DPERF_BeginEvent");
  return f ? f(color, name) : 0;
}

int WINAPI AALight_D3DPERF_EndEvent() {
  auto f = RealProc<int(WINAPI*)()>("D3DPERF_EndEvent");
  return f ? f() : 0;
}

void WINAPI AALight_D3DPERF_SetMarker(D3DCOLOR color, LPCWSTR name) {
  auto f = RealProc<void(WINAPI*)(D3DCOLOR, LPCWSTR)>("D3DPERF_SetMarker");
  if (f) f(color, name);
}

void WINAPI AALight_D3DPERF_SetRegion(D3DCOLOR color, LPCWSTR name) {
  auto f = RealProc<void(WINAPI*)(D3DCOLOR, LPCWSTR)>("D3DPERF_SetRegion");
  if (f) f(color, name);
}

BOOL WINAPI AALight_D3DPERF_QueryRepeatFrame() {
  auto f = RealProc<BOOL(WINAPI*)()>("D3DPERF_QueryRepeatFrame");
  return f ? f() : FALSE;
}

void WINAPI AALight_D3DPERF_SetOptions(DWORD options) {
  auto f = RealProc<void(WINAPI*)(DWORD)>("D3DPERF_SetOptions");
  if (f) f(options);
}

DWORD WINAPI AALight_D3DPERF_GetStatus() {
  auto f = RealProc<DWORD(WINAPI*)()>("D3DPERF_GetStatus");
  return f ? f() : 0;
}

}  // extern "C"

BOOL WINAPI DllMain(HINSTANCE, DWORD reason, LPVOID) {
  if (reason == DLL_PROCESS_DETACH) LogFlush();
  return TRUE;
}
