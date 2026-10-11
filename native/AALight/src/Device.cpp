#include "Device.h"

#include "Capture.h"
#include "Direct3D9.h"
#include "Names.h"

namespace {

// Vertex count of a draw, for the capture log.
UINT Vertices(D3DPRIMITIVETYPE type, UINT count) {
  switch (type) {
    case D3DPT_POINTLIST: return count;
    case D3DPT_LINELIST: return count * 2;
    case D3DPT_LINESTRIP: return count + 1;
    case D3DPT_TRIANGLELIST: return count * 3;
    default: return count + 2;
  }
}

ShaderInfo MakeShaderInfo(const DWORD* function) {
  ShaderInfo info;
  size_t n = 0;
  while (function[n] != D3DSIO_END) {  // tokens up to and including the end token
    DWORD op = function[n] & 0xFFFF;
    n += op == D3DSIO_COMMENT ? 1 + ((function[n] >> 16) & 0x7FFF) : 1;
  }
  info.code.assign(function, function + n + 1);
  info.hash = Fnv1a(info.code.data(), info.code.size() * sizeof(DWORD));
  return info;
}

}  // namespace

Device::Device(IDirect3DDevice9* real, Direct3D9* parent, const D3DPRESENT_PARAMETERS& params)
    : Device9Forward(real), parent_(parent) {
  parent_->AddRef();
  ReadInitialState();
  D3DCAPS9 caps = {};
  real_->GetDeviceCaps(&caps);
  Log("device: %ux%u %s backbuffers=%u msaa=%d windowed=%d depth=%s interval=0x%x", params.BackBufferWidth,
      params.BackBufferHeight, FormatName(params.BackBufferFormat), params.BackBufferCount, params.MultiSampleType,
      params.Windowed, FormatName(params.AutoDepthStencilFormat), params.PresentationInterval);
  Log("caps: vs %u.%u ps %u.%u maxlights=%lu stages=%lu textures=%lu vsconst=%lu", D3DSHADER_VERSION_MAJOR(caps.VertexShaderVersion),
      D3DSHADER_VERSION_MINOR(caps.VertexShaderVersion), D3DSHADER_VERSION_MAJOR(caps.PixelShaderVersion),
      D3DSHADER_VERSION_MINOR(caps.PixelShaderVersion), caps.MaxActiveLights, caps.MaxTextureBlendStages,
      caps.MaxSimultaneousTextures, caps.MaxVertexShaderConst);
  LogFlush();
}

Device::~Device() {
  capture_.reset();
  parent_->Release();
  Log("device released after %u frames", frame_);
  LogFlush();
}

void Device::ReadInitialState() {
  for (DWORD i = 0; i < 256; ++i) real_->GetRenderState(static_cast<D3DRENDERSTATETYPE>(i), &state_.renderStates[i]);
  for (DWORD stage = 0; stage < 8; ++stage)
    for (DWORD type = 1; type < 33; ++type)
      real_->GetTextureStageState(stage, static_cast<D3DTEXTURESTAGESTATETYPE>(type), &state_.stageStates[stage][type]);
  real_->GetMaterial(&state_.material);
  real_->GetTransform(D3DTS_WORLD, &state_.world);
  real_->GetTransform(D3DTS_VIEW, &state_.view);
  real_->GetTransform(D3DTS_PROJECTION, &state_.projection);
  real_->GetFVF(&state_.fvf);
  std::fill(std::begin(state_.textures), std::end(state_.textures), nullptr);
  state_.decl = nullptr;
  state_.vertexShader = nullptr;
  state_.pixelShader = nullptr;
  state_.lights.clear();
  state_.lightEnabled.clear();
}

HRESULT Device::QueryInterface(REFIID riid, void** object) {
  if (!object) return E_POINTER;
  if (riid == IID_IUnknown || riid == IID_IDirect3DDevice9) {
    *object = static_cast<IDirect3DDevice9*>(this);
    AddRef();
    return S_OK;
  }
  Log("device QueryInterface for an unwrapped interface");
  return real_->QueryInterface(riid, object);
}

ULONG Device::AddRef() {
  ++refs_;
  return real_->AddRef();
}

ULONG Device::Release() {
  ULONG left = real_->Release();
  if (--refs_ == 0) {
    if (left) Log("device: game released its last reference, %lu internal references remain", left);
    delete this;
  }
  return left;
}

HRESULT Device::GetDirect3D(IDirect3D9** d3d) {
  if (!d3d) return D3DERR_INVALIDCALL;
  *d3d = parent_;
  parent_->AddRef();
  return D3D_OK;
}

HRESULT Device::Reset(D3DPRESENT_PARAMETERS* params) {
  capture_.reset();
  HRESULT hr = real_->Reset(params);
  Log("reset %ux%u msaa=%d windowed=%d -> 0x%08lx", params->BackBufferWidth, params->BackBufferHeight,
      params->MultiSampleType, params->Windowed, hr);
  if (SUCCEEDED(hr)) ReadInitialState();
  return hr;
}

HRESULT Device::Present(const RECT* source, const RECT* dest, HWND window, const RGNDATA* dirty) {
  if (capture_) {
    capture_->Finish();
    capture_.reset();
  }
  HRESULT hr = real_->Present(source, dest, window, dirty);
  ++frame_;
  if (litDrawsThisFrame_ >= 50) ++litFrames_;  // a battle scene, not a menu
  litDrawsThisFrame_ = 0;
  StartCaptureIfDue();
  return hr;
}

// Ctrl+Shift+F11, CaptureFrame=<n>, or automatically once the game has drawn battle scenes (50+ lit
// draws per frame) for AutoCaptureLitFrames frames.
void Device::StartCaptureIfDue() {
  bool down = (GetAsyncKeyState(VK_CONTROL) & 0x8000) && (GetAsyncKeyState(VK_SHIFT) & 0x8000) &&
              (GetAsyncKeyState(VK_F11) & 0x8000);
  bool pressed = down && !hotkeyDown_;
  hotkeyDown_ = down;
  const Config& config = GetConfig();
  const char* reason = nullptr;
  if (pressed) {
    reason = "hotkey";
  } else if (config.captureFrame && frame_ + 1 == static_cast<unsigned>(config.captureFrame)) {
    reason = "CaptureFrame";
  } else if (!autoCaptured_ && config.autoCaptureLitFrames > 0 && litFrames_ >= static_cast<unsigned>(config.autoCaptureLitFrames)) {
    autoCaptured_ = true;
    reason = "AutoCaptureLitFrames";
  }
  if (reason) capture_ = std::make_unique<FrameCapture>(*this, frame_ + 1, reason);
}

HRESULT Device::GetSwapChain(UINT index, IDirect3DSwapChain9** swapChain) {
  static bool logged = false;
  if (!logged) Log("game asked for swap chain %u (its Present bypasses AALight)", index), logged = true;
  return real_->GetSwapChain(index, swapChain);
}

HRESULT Device::SetRenderTarget(DWORD index, IDirect3DSurface9* target) {
  if (capture_) {
    D3DSURFACE_DESC desc = {};
    if (target) target->GetDesc(&desc);
    capture_->Line("SetRenderTarget %lu %p %ux%u %s msaa=%d", index, target, desc.Width, desc.Height, FormatName(desc.Format), desc.MultiSampleType);
  }
  return real_->SetRenderTarget(index, target);
}

HRESULT Device::SetDepthStencilSurface(IDirect3DSurface9* surface) {
  if (capture_) capture_->Line("SetDepthStencilSurface %p", surface);
  return real_->SetDepthStencilSurface(surface);
}

HRESULT Device::BeginScene() {
  if (capture_) capture_->Line("BeginScene");
  return real_->BeginScene();
}

HRESULT Device::EndScene() {
  if (capture_) capture_->Line("EndScene");
  return real_->EndScene();
}

HRESULT Device::Clear(DWORD count, const D3DRECT* rects, DWORD flags, D3DCOLOR color, float z, DWORD stencil) {
  if (capture_) capture_->Line("Clear rects=%lu flags=0x%lx color=0x%08lx z=%g stencil=%lu", count, flags, color, z, stencil);
  return real_->Clear(count, rects, flags, color, z, stencil);
}

HRESULT Device::SetTransform(D3DTRANSFORMSTATETYPE type, const D3DMATRIX* m) {
  if (m) {
    if (type == D3DTS_WORLD) state_.world = *m;
    else if (type == D3DTS_VIEW) state_.view = *m;
    else if (type == D3DTS_PROJECTION) state_.projection = *m;
    if (capture_ && type != D3DTS_WORLD)
      capture_->Line("SetTransform %s [%g %g %g %g | %g %g %g %g | %g %g %g %g | %g %g %g %g]", TransformName(type),
                     m->_11, m->_12, m->_13, m->_14, m->_21, m->_22, m->_23, m->_24, m->_31, m->_32, m->_33, m->_34,
                     m->_41, m->_42, m->_43, m->_44);
  }
  return real_->SetTransform(type, m);
}

HRESULT Device::SetViewport(const D3DVIEWPORT9* v) {
  if (capture_ && v) capture_->Line("SetViewport %lu,%lu %lux%lu z=%g..%g", v->X, v->Y, v->Width, v->Height, v->MinZ, v->MaxZ);
  return real_->SetViewport(v);
}

HRESULT Device::SetMaterial(const D3DMATERIAL9* material) {
  if (material) {
    if (capture_ && memcmp(material, &state_.material, sizeof(*material)) != 0)
      capture_->Line("SetMaterial %s", FrameCapture::DescribeMaterial(*material).c_str());
    state_.material = *material;
  }
  return real_->SetMaterial(material);
}

HRESULT Device::SetLight(DWORD index, const D3DLIGHT9* light) {
  if (light) {
    auto it = state_.lights.find(index);
    bool changed = it == state_.lights.end() || memcmp(&it->second, light, sizeof(*light)) != 0;
    if (changed) {
      std::string text = FrameCapture::DescribeLight(*light);
      if (capture_) capture_->Line("SetLight %lu %s", index, text.c_str());
      if (GetConfig().logLights && lightLogLines_ < 500) {
        Log("frame %u: light %lu = %s", frame_, index, text.c_str());
        if (++lightLogLines_ == 500) Log("(light log limit reached)");
      }
    }
    state_.lights[index] = *light;
  }
  return real_->SetLight(index, light);
}

HRESULT Device::LightEnable(DWORD index, BOOL enable) {
  if (capture_ && state_.lightEnabled[index] != enable) capture_->Line("LightEnable %lu %d", index, enable);
  state_.lightEnabled[index] = enable;
  return real_->LightEnable(index, enable);
}

HRESULT Device::SetRenderState(D3DRENDERSTATETYPE type, DWORD value) {
  if (type < 256) {
    if (capture_ && state_.renderStates[type] != value) {
      const char* name = RenderStateName(type);
      if (name) capture_->Line("  %s = 0x%lx", name, value);
      else capture_->Line("  renderstate %d = 0x%lx", type, value);
    }
    state_.renderStates[type] = value;
  }
  return real_->SetRenderState(type, value);
}

HRESULT Device::SetTexture(DWORD stage, IDirect3DBaseTexture9* texture) {
  if (stage < 8) state_.textures[stage] = texture;
  return real_->SetTexture(stage, texture);
}

HRESULT Device::SetTextureStageState(DWORD stage, D3DTEXTURESTAGESTATETYPE type, DWORD value) {
  if (stage < 8 && type < 33) state_.stageStates[stage][type] = value;
  return real_->SetTextureStageState(stage, type, value);
}

bool Device::IsLit() const {
  return state_.renderStates[D3DRS_LIGHTING] && !state_.vertexShader && (state_.fvf & D3DFVF_POSITION_MASK) != D3DFVF_XYZRHW;
}

void Device::OnDraw(const char* kind, D3DPRIMITIVETYPE type, UINT count, UINT vertices) {
  if (IsLit()) ++litDrawsThisFrame_;
  if (capture_) capture_->Draw(kind, type, count, vertices);
}

HRESULT Device::DrawPrimitive(D3DPRIMITIVETYPE type, UINT start, UINT count) {
  OnDraw("DP", type, count, Vertices(type, count));
  return real_->DrawPrimitive(type, start, count);
}

HRESULT Device::DrawIndexedPrimitive(D3DPRIMITIVETYPE type, INT baseVertex, UINT minIndex, UINT numVertices, UINT startIndex, UINT count) {
  OnDraw("DIP", type, count, numVertices);
  return real_->DrawIndexedPrimitive(type, baseVertex, minIndex, numVertices, startIndex, count);
}

HRESULT Device::DrawPrimitiveUP(D3DPRIMITIVETYPE type, UINT count, const void* data, UINT stride) {
  state_.streamStride = stride;
  OnDraw("DPUP", type, count, Vertices(type, count));
  return real_->DrawPrimitiveUP(type, count, data, stride);
}

HRESULT Device::DrawIndexedPrimitiveUP(D3DPRIMITIVETYPE type, UINT minIndex, UINT numVertices, UINT count, const void* indices,
                                       D3DFORMAT indexFormat, const void* data, UINT stride) {
  state_.streamStride = stride;
  OnDraw("DIPUP", type, count, numVertices);
  return real_->DrawIndexedPrimitiveUP(type, minIndex, numVertices, count, indices, indexFormat, data, stride);
}

HRESULT Device::SetVertexDeclaration(IDirect3DVertexDeclaration9* decl) {
  state_.decl = decl;
  if (decl) state_.fvf = 0;
  return real_->SetVertexDeclaration(decl);
}

HRESULT Device::SetFVF(DWORD fvf) {
  state_.fvf = fvf;
  if (fvf) state_.decl = nullptr;
  return real_->SetFVF(fvf);
}

HRESULT Device::CreateVertexShader(const DWORD* function, IDirect3DVertexShader9** shader) {
  HRESULT hr = real_->CreateVertexShader(function, shader);
  if (SUCCEEDED(hr) && function && shader && *shader) {
    ShaderInfo info = MakeShaderInfo(function);
    Log("vertex shader %08x created (%zu tokens, vs_%lu_%lu)", info.hash, info.code.size(), D3DSHADER_VERSION_MAJOR(function[0]),
        D3DSHADER_VERSION_MINOR(function[0]));
    vertexShaders_[*shader] = std::move(info);
  }
  return hr;
}

HRESULT Device::SetVertexShader(IDirect3DVertexShader9* shader) {
  state_.vertexShader = shader;
  return real_->SetVertexShader(shader);
}

HRESULT Device::SetVertexShaderConstantF(UINT start, const float* data, UINT count) {
  if (data && start + count <= 256) {
    memcpy(state_.vsConstants[start], data, count * 4 * sizeof(float));
    if (capture_) {
      if (count <= 4) {
        for (UINT i = 0; i < count; ++i)
          capture_->Line("  c%u = (%g %g %g %g)", start + i, data[i * 4], data[i * 4 + 1], data[i * 4 + 2], data[i * 4 + 3]);
      } else {
        capture_->Line("  c%u..c%u (%u registers)", start, start + count - 1, count);
      }
    }
  }
  return real_->SetVertexShaderConstantF(start, data, count);
}

HRESULT Device::SetStreamSource(UINT stream, IDirect3DVertexBuffer9* buffer, UINT offset, UINT stride) {
  if (stream == 0) state_.streamStride = stride;
  return real_->SetStreamSource(stream, buffer, offset, stride);
}

HRESULT Device::CreatePixelShader(const DWORD* function, IDirect3DPixelShader9** shader) {
  HRESULT hr = real_->CreatePixelShader(function, shader);
  if (SUCCEEDED(hr) && function && shader && *shader) {
    ShaderInfo info = MakeShaderInfo(function);
    Log("pixel shader %08x created (%zu tokens, ps_%lu_%lu)", info.hash, info.code.size(), D3DSHADER_VERSION_MAJOR(function[0]),
        D3DSHADER_VERSION_MINOR(function[0]));
    pixelShaders_[*shader] = std::move(info);
  }
  return hr;
}

HRESULT Device::SetPixelShader(IDirect3DPixelShader9* shader) {
  state_.pixelShader = shader;
  return real_->SetPixelShader(shader);
}
