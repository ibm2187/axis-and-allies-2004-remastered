#pragma once
#include "Common.h"
#include "Forward.h"

// Wraps the real IDirect3D9 so that CreateDevice hands the game an AALight Device.
class Direct3D9 final : public Direct3D9Forward {
public:
  explicit Direct3D9(IDirect3D9* real) : Direct3D9Forward(real) {}

  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID riid, void** object) override;
  ULONG STDMETHODCALLTYPE AddRef() override;
  ULONG STDMETHODCALLTYPE Release() override;
  HRESULT STDMETHODCALLTYPE CreateDevice(UINT adapter, D3DDEVTYPE type, HWND window, DWORD flags,
                                         D3DPRESENT_PARAMETERS* params, IDirect3DDevice9** device) override;

private:
  ULONG refs_ = 1;
};
