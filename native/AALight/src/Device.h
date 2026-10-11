#pragma once
#include "Common.h"
#include "Forward.h"

#include <cstdio>
#include <map>
#include <memory>
#include <vector>

class Direct3D9;

// The fixed-function and shader state AALight tracks, mirrored from the calls the game makes.
struct DeviceState {
  DWORD renderStates[256] = {};
  DWORD stageStates[8][33] = {};
  IDirect3DBaseTexture9* textures[8] = {};
  DWORD fvf = 0;
  IDirect3DVertexDeclaration9* decl = nullptr;
  IDirect3DVertexShader9* vertexShader = nullptr;
  IDirect3DPixelShader9* pixelShader = nullptr;
  std::map<DWORD, D3DLIGHT9> lights;
  std::map<DWORD, BOOL> lightEnabled;
  D3DMATERIAL9 material = {};
  D3DMATRIX world = {}, view = {}, projection = {};
  float vsConstants[256][4] = {};
  UINT streamStride = 0;
};

struct ShaderInfo {
  uint32_t hash = 0;
  std::vector<DWORD> code;
};

// One frame written to <game>\AALight\capture-<time>\: frame.log (every state change and draw),
// permutations.log (distinct fixed-function setups), screenshots, shader bytecode.
class FrameCapture;

class Device final : public Device9Forward {
public:
  Device(IDirect3DDevice9* real, Direct3D9* parent, const D3DPRESENT_PARAMETERS& params);
  ~Device() override;

  // IUnknown
  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID riid, void** object) override;
  ULONG STDMETHODCALLTYPE AddRef() override;
  ULONG STDMETHODCALLTYPE Release() override;

  // Device
  HRESULT STDMETHODCALLTYPE GetDirect3D(IDirect3D9** d3d) override;
  HRESULT STDMETHODCALLTYPE Reset(D3DPRESENT_PARAMETERS* params) override;
  HRESULT STDMETHODCALLTYPE Present(const RECT* source, const RECT* dest, HWND window, const RGNDATA* dirty) override;
  HRESULT STDMETHODCALLTYPE GetSwapChain(UINT index, IDirect3DSwapChain9** swapChain) override;
  HRESULT STDMETHODCALLTYPE SetRenderTarget(DWORD index, IDirect3DSurface9* target) override;
  HRESULT STDMETHODCALLTYPE SetDepthStencilSurface(IDirect3DSurface9* surface) override;
  HRESULT STDMETHODCALLTYPE BeginScene() override;
  HRESULT STDMETHODCALLTYPE EndScene() override;
  HRESULT STDMETHODCALLTYPE Clear(DWORD count, const D3DRECT* rects, DWORD flags, D3DCOLOR color, float z, DWORD stencil) override;
  HRESULT STDMETHODCALLTYPE SetTransform(D3DTRANSFORMSTATETYPE state, const D3DMATRIX* matrix) override;
  HRESULT STDMETHODCALLTYPE SetViewport(const D3DVIEWPORT9* viewport) override;
  HRESULT STDMETHODCALLTYPE SetMaterial(const D3DMATERIAL9* material) override;
  HRESULT STDMETHODCALLTYPE SetLight(DWORD index, const D3DLIGHT9* light) override;
  HRESULT STDMETHODCALLTYPE LightEnable(DWORD index, BOOL enable) override;
  HRESULT STDMETHODCALLTYPE SetRenderState(D3DRENDERSTATETYPE state, DWORD value) override;
  HRESULT STDMETHODCALLTYPE SetTexture(DWORD stage, IDirect3DBaseTexture9* texture) override;
  HRESULT STDMETHODCALLTYPE SetTextureStageState(DWORD stage, D3DTEXTURESTAGESTATETYPE type, DWORD value) override;
  HRESULT STDMETHODCALLTYPE DrawPrimitive(D3DPRIMITIVETYPE type, UINT start, UINT count) override;
  HRESULT STDMETHODCALLTYPE DrawIndexedPrimitive(D3DPRIMITIVETYPE type, INT baseVertex, UINT minIndex, UINT numVertices, UINT startIndex, UINT count) override;
  HRESULT STDMETHODCALLTYPE DrawPrimitiveUP(D3DPRIMITIVETYPE type, UINT count, const void* data, UINT stride) override;
  HRESULT STDMETHODCALLTYPE DrawIndexedPrimitiveUP(D3DPRIMITIVETYPE type, UINT minIndex, UINT numVertices, UINT count, const void* indices, D3DFORMAT indexFormat, const void* data, UINT stride) override;
  HRESULT STDMETHODCALLTYPE SetVertexDeclaration(IDirect3DVertexDeclaration9* decl) override;
  HRESULT STDMETHODCALLTYPE SetFVF(DWORD fvf) override;
  HRESULT STDMETHODCALLTYPE CreateVertexShader(const DWORD* function, IDirect3DVertexShader9** shader) override;
  HRESULT STDMETHODCALLTYPE SetVertexShader(IDirect3DVertexShader9* shader) override;
  HRESULT STDMETHODCALLTYPE SetVertexShaderConstantF(UINT start, const float* data, UINT count) override;
  HRESULT STDMETHODCALLTYPE SetStreamSource(UINT stream, IDirect3DVertexBuffer9* buffer, UINT offset, UINT stride) override;
  HRESULT STDMETHODCALLTYPE CreatePixelShader(const DWORD* function, IDirect3DPixelShader9** shader) override;
  HRESULT STDMETHODCALLTYPE SetPixelShader(IDirect3DPixelShader9* shader) override;

private:
  void ReadInitialState();
  void OnDraw(const char* kind, D3DPRIMITIVETYPE type, UINT count, UINT vertices);
  bool IsLit() const;
  void StartCaptureIfDue();

  ULONG refs_ = 1;
  Direct3D9* parent_;
  DeviceState state_;
  std::map<IDirect3DVertexShader9*, ShaderInfo> vertexShaders_;
  std::map<IDirect3DPixelShader9*, ShaderInfo> pixelShaders_;
  std::unique_ptr<FrameCapture> capture_;
  unsigned frame_ = 0;
  unsigned litFrames_ = 0;
  unsigned litDrawsThisFrame_ = 0;
  bool autoCaptured_ = false;
  bool hotkeyDown_ = false;
  unsigned lightLogLines_ = 0;
  friend class FrameCapture;
};
