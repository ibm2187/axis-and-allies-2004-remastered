#include "Direct3D9.h"

#include "Device.h"

HRESULT Direct3D9::QueryInterface(REFIID riid, void** object) {
  if (!object) return E_POINTER;
  if (riid == IID_IUnknown || riid == IID_IDirect3D9) {
    *object = static_cast<IDirect3D9*>(this);
    AddRef();
    return S_OK;
  }
  Log("IDirect3D9 QueryInterface for an unwrapped interface");
  return real_->QueryInterface(riid, object);
}

ULONG Direct3D9::AddRef() {
  ++refs_;
  return real_->AddRef();
}

ULONG Direct3D9::Release() {
  ULONG left = real_->Release();
  if (--refs_ == 0) delete this;
  return left;
}

HRESULT Direct3D9::CreateDevice(UINT adapter, D3DDEVTYPE type, HWND window, DWORD flags, D3DPRESENT_PARAMETERS* params,
                                IDirect3DDevice9** device) {
  if (!params || !device) return D3DERR_INVALIDCALL;
  IDirect3DDevice9* real = nullptr;
  HRESULT hr = real_->CreateDevice(adapter, type, window, flags, params, &real);
  Log("CreateDevice adapter=%u type=%d flags=0x%lx -> 0x%08lx", adapter, type, flags, hr);
  if (FAILED(hr)) {
    *device = nullptr;
    return hr;
  }
  *device = new Device(real, this, *params);
  return hr;
}
