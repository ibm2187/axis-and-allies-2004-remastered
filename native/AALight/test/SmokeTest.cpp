// Smoke test for AALight without the game: loads D3D9.dll from the folder given on the command
// line (AALight, which chains to the real Direct3D 9), draws a fixed-function lit triangle and a
// screen-space quad for a few frames, and checks the pixel colours.
//   SmokeTest.exe <folder with D3D9.dll and AALight.ini>
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <d3d9.h>

#include <cstdio>
#include <string>

namespace {

struct LitVertex { float x, y, z, nx, ny, nz; };
struct ScreenVertex { float x, y, z, rhw; DWORD color; };

int Fail(const char* what, HRESULT hr = S_OK) {
  printf("FAIL: %s (0x%08lx)\n", what, hr);
  return 1;
}

DWORD ReadPixel(IDirect3DDevice9* device, int x, int y) {
  IDirect3DSurface9 *back = nullptr, *system = nullptr;
  D3DSURFACE_DESC desc;
  DWORD pixel = 0xDEADBEEF;
  device->GetBackBuffer(0, 0, D3DBACKBUFFER_TYPE_MONO, &back);
  back->GetDesc(&desc);
  device->CreateOffscreenPlainSurface(desc.Width, desc.Height, desc.Format, D3DPOOL_SYSTEMMEM, &system, nullptr);
  D3DLOCKED_RECT lock;
  if (SUCCEEDED(device->GetRenderTargetData(back, system)) && SUCCEEDED(system->LockRect(&lock, nullptr, D3DLOCK_READONLY))) {
    pixel = *reinterpret_cast<DWORD*>(static_cast<BYTE*>(lock.pBits) + y * lock.Pitch + x * 4) & 0xFFFFFF;
    system->UnlockRect();
  }
  system->Release();
  back->Release();
  return pixel;
}

bool Near(DWORD pixel, DWORD expected) {
  for (int shift = 0; shift < 24; shift += 8) {
    int a = (pixel >> shift) & 0xFF, b = (expected >> shift) & 0xFF;
    if (abs(a - b) > 3) return false;
  }
  return true;
}

}  // namespace

int wmain(int argc, wchar_t** argv) {
  if (argc < 2) return Fail("usage: SmokeTest.exe <folder>");
  std::wstring dll = std::wstring(argv[1]) + L"\\D3D9.dll";
  HMODULE module = LoadLibraryW(dll.c_str());
  if (!module) return Fail("LoadLibrary D3D9.dll", GetLastError());
  auto create = reinterpret_cast<IDirect3D9*(WINAPI*)(UINT)>(GetProcAddress(module, "Direct3DCreate9"));
  if (!create) return Fail("Direct3DCreate9 export");

  WNDCLASSW wc = {};
  wc.lpfnWndProc = DefWindowProcW;
  wc.hInstance = GetModuleHandleW(nullptr);
  wc.lpszClassName = L"AALightSmokeTest";
  RegisterClassW(&wc);
  HWND window = CreateWindowW(wc.lpszClassName, L"AALight smoke test", WS_OVERLAPPEDWINDOW, 0, 0, 320, 240, nullptr, nullptr, wc.hInstance, nullptr);

  IDirect3D9* d3d = create(D3D_SDK_VERSION);
  if (!d3d) return Fail("Direct3DCreate9");
  D3DPRESENT_PARAMETERS pp = {};
  pp.Windowed = TRUE;
  pp.SwapEffect = D3DSWAPEFFECT_DISCARD;
  pp.BackBufferWidth = 256;
  pp.BackBufferHeight = 256;
  pp.BackBufferFormat = D3DFMT_X8R8G8B8;
  pp.EnableAutoDepthStencil = TRUE;
  pp.AutoDepthStencilFormat = D3DFMT_D24S8;
  pp.Flags = D3DPRESENTFLAG_LOCKABLE_BACKBUFFER;
  pp.PresentationInterval = D3DPRESENT_INTERVAL_IMMEDIATE;
  IDirect3DDevice9* device = nullptr;
  HRESULT hr = d3d->CreateDevice(D3DADAPTER_DEFAULT, D3DDEVTYPE_HAL, window, D3DCREATE_HARDWARE_VERTEXPROCESSING, &pp, &device);
  if (FAILED(hr)) return Fail("CreateDevice", hr);

  // Sun straight into the screen, half grey ambient through the light, white material:
  // lit colour = 0.25 ambient + 0.5 diffuse = 0.75 -> 0xBF.
  D3DLIGHT9 sun = {};
  sun.Type = D3DLIGHT_DIRECTIONAL;
  sun.Diffuse = {0.5f, 0.5f, 0.5f, 1};
  sun.Ambient = {0.25f, 0.25f, 0.25f, 1};
  sun.Direction = {0, 0, 1};
  D3DMATERIAL9 material = {};
  material.Diffuse = material.Ambient = {1, 1, 1, 1};
  D3DMATRIX identity = {1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1};
  LitVertex triangle[] = {{-1, -1, 0.5f, 0, 0, -1}, {0, 1, 0.5f, 0, 0, -1}, {1, -1, 0.5f, 0, 0, -1}};
  ScreenVertex quad[] = {{0, 0, 0, 1, 0xFF00FF00}, {32, 0, 0, 1, 0xFF00FF00}, {0, 32, 0, 1, 0xFF00FF00}, {32, 32, 0, 1, 0xFF00FF00}};

  DWORD lit = 0, ui = 0;
  for (int frame = 1; frame <= 5; ++frame) {
    device->Clear(0, nullptr, D3DCLEAR_TARGET | D3DCLEAR_ZBUFFER, 0xFF000040, 1, 0);
    device->BeginScene();
    device->SetTransform(D3DTS_WORLD, &identity);
    device->SetTransform(D3DTS_VIEW, &identity);
    device->SetTransform(D3DTS_PROJECTION, &identity);
    device->SetRenderState(D3DRS_LIGHTING, TRUE);
    device->SetRenderState(D3DRS_CULLMODE, D3DCULL_NONE);
    device->SetRenderState(D3DRS_AMBIENT, 0);
    device->SetLight(0, &sun);
    device->LightEnable(0, TRUE);
    device->SetMaterial(&material);
    device->SetTextureStageState(0, D3DTSS_COLOROP, D3DTOP_SELECTARG1);
    device->SetTextureStageState(0, D3DTSS_COLORARG1, D3DTA_DIFFUSE);
    device->SetFVF(D3DFVF_XYZ | D3DFVF_NORMAL);
    device->DrawPrimitiveUP(D3DPT_TRIANGLELIST, 1, triangle, sizeof(LitVertex));
    device->SetRenderState(D3DRS_LIGHTING, FALSE);
    device->SetFVF(D3DFVF_XYZRHW | D3DFVF_DIFFUSE);
    device->DrawPrimitiveUP(D3DPT_TRIANGLESTRIP, 2, quad, sizeof(ScreenVertex));
    device->EndScene();
    if (frame == 5) {
      lit = ReadPixel(device, 128, 140);
      ui = ReadPixel(device, 8, 8);
    }
    hr = device->Present(nullptr, nullptr, nullptr, nullptr);
    if (FAILED(hr)) return Fail("Present", hr);
  }
  printf("lit pixel 0x%06lx (expected 0xbfbfbf), screen-space pixel 0x%06lx (expected 0x00ff00)\n", lit, ui);
  device->Release();
  d3d->Release();
  DestroyWindow(window);
  if (!Near(lit, 0xBFBFBF) || !Near(ui, 0x00FF00)) return Fail("pixel colours");
  printf("PASS\n");
  return 0;
}
