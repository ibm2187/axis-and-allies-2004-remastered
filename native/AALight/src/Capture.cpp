#include "Capture.h"

#include "Names.h"

#include <algorithm>
#include <cstdarg>
#include <vector>

namespace {

std::string Format(const char* format, ...) {
  char buffer[1024];
  va_list args;
  va_start(args, format);
  vsnprintf(buffer, sizeof(buffer), format, args);
  va_end(args);
  return buffer;
}

std::string Color(const D3DCOLORVALUE& c) { return Format("(%.3g %.3g %.3g %.3g)", c.r, c.g, c.b, c.a); }
std::string Vector(const D3DVECTOR& v) { return Format("(%.3g %.3g %.3g)", v.x, v.y, v.z); }

std::wstring NewCaptureDir() {
  SYSTEMTIME t;
  GetLocalTime(&t);
  wchar_t name[64];
  swprintf_s(name, L"capture-%04d%02d%02d-%02d%02d%02d", t.wYear, t.wMonth, t.wDay, t.wHour, t.wMinute, t.wSecond);
  std::wstring root = L"\\\\?\\" + ModuleDir() + L"AALight\\";  // long-path prefix: deep game folders
  CreateDirectoryW(root.c_str(), nullptr);
  std::wstring dir = root + name + L"\\";
  CreateDirectoryW(dir.c_str(), nullptr);
  return dir;
}

void WriteFile(const std::wstring& path, const void* data, size_t size) {
  FILE* f = _wfopen(path.c_str(), L"wb");
  if (!f) {
    Log("cannot write %ls (errno %d)", path.c_str(), errno);
    return;
  }
  fwrite(data, 1, size, f);
  fclose(f);
}

}  // namespace

std::string FrameCapture::DescribeLight(const D3DLIGHT9& l) {
  static const char* types[] = {"?", "POINT", "SPOT", "DIRECTIONAL"};
  std::string s = Format("%s diffuse=%s ambient=%s specular=%s", types[l.Type <= 3 ? l.Type : 0],
                         Color(l.Diffuse).c_str(), Color(l.Ambient).c_str(), Color(l.Specular).c_str());
  if (l.Type != D3DLIGHT_POINT) s += " dir=" + Vector(l.Direction);
  if (l.Type != D3DLIGHT_DIRECTIONAL)
    s += " pos=" + Vector(l.Position) + Format(" range=%g atten=(%g %g %g)", l.Range, l.Attenuation0, l.Attenuation1, l.Attenuation2);
  if (l.Type == D3DLIGHT_SPOT) s += Format(" falloff=%g theta=%g phi=%g", l.Falloff, l.Theta, l.Phi);
  return s;
}

std::string FrameCapture::DescribeMaterial(const D3DMATERIAL9& m) {
  return Format("diffuse=%s ambient=%s specular=%s emissive=%s power=%g", Color(m.Diffuse).c_str(),
                Color(m.Ambient).c_str(), Color(m.Specular).c_str(), Color(m.Emissive).c_str(), m.Power);
}

FrameCapture::FrameCapture(Device& device, unsigned frame, const char* reason) : device_(device), dir_(NewCaptureDir()) {
  file_ = _wfopen((dir_ + L"frame.log").c_str(), L"w");
  Line("AALight frame capture: frame %u (%s)", frame, reason);
  const DeviceState& s = device_.state_;
  for (auto& [index, light] : s.lights)
    Line("  light %lu %s: %s", index, s.lightEnabled.count(index) && s.lightEnabled.at(index) ? "on" : "off", DescribeLight(light).c_str());
  Line("  material %s", DescribeMaterial(s.material).c_str());
  Log("capture started (%s) -> %ls", reason, dir_.c_str());
}

FrameCapture::~FrameCapture() {
  if (file_) fclose(file_);
  Log("capture written: %u draws, %zu permutations", draws_, permutations_.size());
  LogFlush();
}

void FrameCapture::Line(const char* format, ...) {
  if (!file_) return;
  va_list args;
  va_start(args, format);
  vfprintf(file_, format, args);
  va_end(args);
  fputc('\n', file_);
}

const FrameCapture::DeclInfo& FrameCapture::Decl(IDirect3DVertexDeclaration9* decl) {
  auto it = decls_.find(decl);
  if (it != decls_.end()) return it->second;
  DeclInfo info;
  info.id = static_cast<int>(decls_.size()) + 1;
  D3DVERTEXELEMENT9 elements[MAXD3DDECLLENGTH + 1];
  UINT count = MAXD3DDECLLENGTH + 1;
  if (SUCCEEDED(decl->GetDeclaration(elements, &count))) {
    for (UINT i = 0; i < count && elements[i].Stream != 0xFF; ++i) {
      const auto& e = elements[i];
      info.signature += Format("%s%u:%u:%s:%s%u", info.signature.empty() ? "" : " ", e.Stream, e.Offset,
                               DeclTypeName(e.Type), DeclUsageName(e.Usage), e.UsageIndex);
      if (e.Usage == D3DDECLUSAGE_POSITIONT) info.screenSpace = true;
    }
  }
  Line("  decl D%d = %s", info.id, info.signature.c_str());
  return decls_.emplace(decl, info).first->second;
}

bool FrameCapture::ScreenSpace() {
  const DeviceState& s = device_.state_;
  if (s.decl) return Decl(s.decl).screenSpace;
  return (s.fvf & D3DFVF_POSITION_MASK) == D3DFVF_XYZRHW;
}

std::string FrameCapture::Texture(IDirect3DBaseTexture9* texture) {
  if (!texture) return "none";
  auto [it, added] = textures_.emplace(texture, static_cast<int>(textures_.size()) + 1);
  std::string name = Format("T%d", it->second);
  if (!added) return name;
  std::string detail;
  if (texture->GetType() == D3DRTYPE_TEXTURE) {
    D3DSURFACE_DESC desc;
    if (SUCCEEDED(static_cast<IDirect3DTexture9*>(texture)->GetLevelDesc(0, &desc)))
      detail = Format("%ux%u %s mips=%lu%s", desc.Width, desc.Height, FormatName(desc.Format), texture->GetLevelCount(),
                      desc.Usage & D3DUSAGE_RENDERTARGET ? " rendertarget" : "");
  } else if (texture->GetType() == D3DRTYPE_CUBETEXTURE) {
    detail = "cube";
  } else {
    detail = "volume";
  }
  Line("  texture %s = %s", name.c_str(), detail.c_str());
  return name;
}

std::string FrameCapture::ShaderName(bool vertex, void* shader) {
  if (!shader) return "FF";
  const ShaderInfo* info = nullptr;
  if (vertex) {
    auto it = device_.vertexShaders_.find(static_cast<IDirect3DVertexShader9*>(shader));
    if (it != device_.vertexShaders_.end()) info = &it->second;
  } else {
    auto it = device_.pixelShaders_.find(static_cast<IDirect3DPixelShader9*>(shader));
    if (it != device_.pixelShaders_.end()) info = &it->second;
  }
  if (!info) return "unknown";
  if (savedShaders_.insert(info->hash).second) {
    wchar_t name[32];
    swprintf_s(name, vertex ? L"vs_%08x.vso" : L"ps_%08x.pso", info->hash);
    WriteFile(dir_ + name, info->code.data(), info->code.size() * sizeof(DWORD));
  }
  return Format("%08x", info->hash);
}

std::string FrameCapture::Stages() {
  const DeviceState& s = device_.state_;
  std::string out;
  for (int i = 0; i < 8; ++i) {
    const DWORD* t = s.stageStates[i];
    if (t[D3DTSS_COLOROP] == D3DTOP_DISABLE) break;
    out += Format(" s%d[%s C=%s(%s,%s) A=%s(%s,%s)", i, Texture(s.textures[i]).c_str(), TextureOpName(t[D3DTSS_COLOROP]),
                  TextureArgName(t[D3DTSS_COLORARG1]).c_str(), TextureArgName(t[D3DTSS_COLORARG2]).c_str(),
                  TextureOpName(t[D3DTSS_ALPHAOP]), TextureArgName(t[D3DTSS_ALPHAARG1]).c_str(),
                  TextureArgName(t[D3DTSS_ALPHAARG2]).c_str());
    if (t[D3DTSS_TEXCOORDINDEX] != static_cast<DWORD>(i)) out += Format(" tci=0x%lx", t[D3DTSS_TEXCOORDINDEX]);
    if (t[D3DTSS_TEXTURETRANSFORMFLAGS]) out += Format(" ttf=%lu", t[D3DTSS_TEXTURETRANSFORMFLAGS]);
    if (t[D3DTSS_RESULTARG] != D3DTA_CURRENT) out += " result=" + TextureArgName(t[D3DTSS_RESULTARG]);
    out += "]";
  }
  return out;
}

// Everything that changes which shader the fixed-function pipeline would need; not textures,
// matrices, light or material values.
std::string FrameCapture::PermutationKey(bool screenSpace) {
  const DeviceState& s = device_.state_;
  const DWORD* rs = s.renderStates;
  std::string key = "vs=" + ShaderName(true, s.vertexShader) + " ps=" + ShaderName(false, s.pixelShader);
  key += s.decl ? " in=" + Decl(s.decl).signature : Format(" fvf=0x%lx", s.fvf);
  if (screenSpace) key += " screen";
  if (rs[D3DRS_LIGHTING] && !s.vertexShader && !screenSpace) {
    int directional = 0, point = 0, spot = 0;
    for (auto& [index, on] : s.lightEnabled) {
      if (!on || !s.lights.count(index)) continue;
      D3DLIGHTTYPE type = s.lights.at(index).Type;
      (type == D3DLIGHT_DIRECTIONAL ? directional : type == D3DLIGHT_POINT ? point : spot)++;
    }
    key += Format(" LIT dir=%d point=%d spot=%d spec=%lu colorvertex=%lu src=%lu%lu%lu%lu normalize=%lu localviewer=%lu",
                  directional, point, spot, rs[D3DRS_SPECULARENABLE], rs[D3DRS_COLORVERTEX],
                  rs[D3DRS_DIFFUSEMATERIALSOURCE], rs[D3DRS_AMBIENTMATERIALSOURCE], rs[D3DRS_SPECULARMATERIALSOURCE],
                  rs[D3DRS_EMISSIVEMATERIALSOURCE], rs[D3DRS_NORMALIZENORMALS], rs[D3DRS_LOCALVIEWER]);
  } else if (!s.vertexShader && !screenSpace) {
    key += " UNLIT";
  }
  if (rs[D3DRS_VERTEXBLEND]) key += Format(" vertexblend=%lu", rs[D3DRS_VERTEXBLEND]);
  if (rs[D3DRS_FOGENABLE]) key += Format(" fog(table=%lu vertex=%lu)", rs[D3DRS_FOGTABLEMODE], rs[D3DRS_FOGVERTEXMODE]);
  if (rs[D3DRS_ALPHABLENDENABLE])
    key += Format(" blend=%s/%s", BlendName(rs[D3DRS_SRCBLEND]), BlendName(rs[D3DRS_DESTBLEND]));
  if (rs[D3DRS_ALPHATESTENABLE]) key += Format(" alphatest=%lu/%lu", rs[D3DRS_ALPHAFUNC], rs[D3DRS_ALPHAREF]);
  if (rs[D3DRS_STENCILENABLE]) key += " stencil";
  if (rs[D3DRS_COLORWRITEENABLE] != 0xF) key += Format(" colorwrite=0x%lx", rs[D3DRS_COLORWRITEENABLE]);
  key += Format(" z=%lu/%lu", rs[D3DRS_ZENABLE], rs[D3DRS_ZWRITEENABLE]);
  for (int i = 0; i < 8; ++i) {  // stage setup without texture identity
    const DWORD* t = s.stageStates[i];
    if (t[D3DTSS_COLOROP] == D3DTOP_DISABLE) break;
    key += Format(" s%d[%s %s(%s,%s) %s(%s,%s) tci=0x%lx ttf=%lu]", i, s.textures[i] ? "tex" : "-",
                  TextureOpName(t[D3DTSS_COLOROP]), TextureArgName(t[D3DTSS_COLORARG1]).c_str(),
                  TextureArgName(t[D3DTSS_COLORARG2]).c_str(), TextureOpName(t[D3DTSS_ALPHAOP]),
                  TextureArgName(t[D3DTSS_ALPHAARG1]).c_str(), TextureArgName(t[D3DTSS_ALPHAARG2]).c_str(),
                  t[D3DTSS_TEXCOORDINDEX], t[D3DTSS_TEXTURETRANSFORMFLAGS]);
  }
  return key;
}

void FrameCapture::Draw(const char* kind, D3DPRIMITIVETYPE type, UINT count, UINT vertices) {
  ++draws_;
  bool screenSpace = ScreenSpace();
  if (!screenSpace) {
    ++worldDraws_;
  } else if (!sceneShot_ && worldDraws_ > 0) {
    sceneShot_ = true;  // first UI draw after the 3D scene: keep the scene without the HUD
    IDirect3DSurface9* target = nullptr;
    if (SUCCEEDED(device_.Real()->GetRenderTarget(0, &target))) {
      Line("  -- first screen-space draw after %u world draws: scene.tga --", worldDraws_);
      Screenshot(target, L"scene.tga");
      target->Release();
    }
  }
  std::string key = PermutationKey(screenSpace);
  auto [it, added] = permutations_.try_emplace(key);
  Permutation& p = it->second;
  if (added) {
    p.id = static_cast<int>(permutations_.size());
    p.firstDraw = draws_;
  }
  ++p.draws;
  p.primitives += count;

  const DeviceState& s = device_.state_;
  std::string line = Format("#%u %s P%d prim=%d count=%u verts=%u stride=%u vs=%s ps=%s", draws_, kind, p.id, type, count,
                            vertices, s.streamStride, ShaderName(true, s.vertexShader).c_str(),
                            ShaderName(false, s.pixelShader).c_str());
  line += s.decl ? Format(" decl=D%d", Decl(s.decl).id) : Format(" fvf=0x%lx", s.fvf);
  if (!s.vertexShader && !screenSpace)
    line += Format(" lit=%lu at=(%.4g %.4g %.4g)", s.renderStates[D3DRS_LIGHTING], s.world._41, s.world._42, s.world._43);
  line += Stages();
  Line("%s", line.c_str());
  if (added) p.example = line;
}

void FrameCapture::Finish() {
  IDirect3DSurface9* back = nullptr;
  if (SUCCEEDED(device_.Real()->GetBackBuffer(0, 0, D3DBACKBUFFER_TYPE_MONO, &back))) {
    Screenshot(back, L"frame.tga");
    back->Release();
  }
  FILE* f = _wfopen((dir_ + L"permutations.log").c_str(), L"w");
  if (!f) {
    Log("cannot write permutations.log (errno %d)", errno);
    return;
  }
  std::vector<const std::pair<const std::string, Permutation>*> sorted;
  for (auto& entry : permutations_) sorted.push_back(&entry);
  std::sort(sorted.begin(), sorted.end(), [](auto a, auto b) { return a->second.id < b->second.id; });
  fprintf(f, "%zu permutations over %u draws (%u world)\n\n", sorted.size(), draws_, worldDraws_);
  for (auto* entry : sorted) {
    const Permutation& p = entry->second;
    fprintf(f, "P%d draws=%u primitives=%u first=#%u\n  key: %s\n  example: %s\n\n", p.id, p.draws, p.primitives,
            p.firstDraw, entry->first.c_str(), p.example.c_str());
  }
  fclose(f);
}

// 32-bit TGA of a render target (resolving multisampling first).
void FrameCapture::Screenshot(IDirect3DSurface9* surface, const wchar_t* name) {
  IDirect3DDevice9* d = device_.Real();
  D3DSURFACE_DESC desc;
  if (FAILED(surface->GetDesc(&desc))) return;
  if (desc.Format != D3DFMT_X8R8G8B8 && desc.Format != D3DFMT_A8R8G8B8) {
    Line("  (screenshot %ls skipped: format %s)", name, FormatName(desc.Format));
    return;
  }
  IDirect3DSurface9* resolved = nullptr;
  IDirect3DSurface9* system = nullptr;
  IDirect3DSurface9* source = surface;
  if (desc.MultiSampleType != D3DMULTISAMPLE_NONE) {
    if (FAILED(d->CreateRenderTarget(desc.Width, desc.Height, desc.Format, D3DMULTISAMPLE_NONE, 0, FALSE, &resolved, nullptr)) ||
        FAILED(d->StretchRect(surface, nullptr, resolved, nullptr, D3DTEXF_NONE))) {
      if (resolved) resolved->Release();
      Line("  (screenshot %ls failed: resolve)", name);
      return;
    }
    source = resolved;
  }
  D3DLOCKED_RECT lock;
  if (SUCCEEDED(d->CreateOffscreenPlainSurface(desc.Width, desc.Height, desc.Format, D3DPOOL_SYSTEMMEM, &system, nullptr)) &&
      SUCCEEDED(d->GetRenderTargetData(source, system)) && SUCCEEDED(system->LockRect(&lock, nullptr, D3DLOCK_READONLY))) {
    std::vector<uint8_t> tga(18 + desc.Width * desc.Height * 4);
    tga[2] = 2;  // uncompressed true colour
    tga[12] = static_cast<uint8_t>(desc.Width), tga[13] = static_cast<uint8_t>(desc.Width >> 8);
    tga[14] = static_cast<uint8_t>(desc.Height), tga[15] = static_cast<uint8_t>(desc.Height >> 8);
    tga[16] = 32, tga[17] = 0x28;  // 8 alpha bits, top-left origin
    for (UINT y = 0; y < desc.Height; ++y) {
      const uint8_t* row = static_cast<const uint8_t*>(lock.pBits) + y * lock.Pitch;
      uint8_t* out = tga.data() + 18 + y * desc.Width * 4;
      memcpy(out, row, desc.Width * 4);
      for (UINT x = 0; x < desc.Width; ++x) out[x * 4 + 3] = 0xFF;
    }
    system->UnlockRect();
    WriteFile(dir_ + name, tga.data(), tga.size());
  } else {
    Line("  (screenshot %ls failed: readback)", name);
  }
  if (system) system->Release();
  if (resolved) resolved->Release();
}
