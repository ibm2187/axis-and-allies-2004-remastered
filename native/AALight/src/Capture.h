#pragma once
#include "Device.h"

#include <set>
#include <string>

// Writes everything one frame does to <game>\AALight\capture-<time>\:
//   frame.log         every state change and draw, in order
//   permutations.log  the distinct fixed-function / shader setups with draw counts
//   scene.tga         the back buffer just before the first screen-space (UI) draw
//   frame.tga         the finished frame, before Present
//   vs_<hash>.vso     vertex shader bytecode used in the frame (ps_<hash>.pso likewise)
class FrameCapture {
public:
  FrameCapture(Device& device, unsigned frame, const char* reason);
  ~FrameCapture();

  void Line(const char* format, ...);
  void Draw(const char* kind, D3DPRIMITIVETYPE type, UINT count, UINT vertices);
  void Finish();  // before Present: frame screenshot and permutation summary

  // Shared with the device's light logging.
  static std::string DescribeLight(const D3DLIGHT9& light);
  static std::string DescribeMaterial(const D3DMATERIAL9& material);

private:
  struct Permutation {
    int id = 0;
    unsigned draws = 0, primitives = 0;
    unsigned firstDraw = 0;
    std::string example;
  };
  struct DeclInfo {
    int id = 0;
    bool screenSpace = false;
    std::string signature;
  };

  bool ScreenSpace();
  const DeclInfo& Decl(IDirect3DVertexDeclaration9* decl);
  std::string Texture(IDirect3DBaseTexture9* texture);
  std::string ShaderName(bool vertex, void* shader);
  std::string PermutationKey(bool screenSpace);
  std::string Stages();
  void Screenshot(IDirect3DSurface9* surface, const wchar_t* name);

  Device& device_;
  std::wstring dir_;
  FILE* file_ = nullptr;
  unsigned draws_ = 0, worldDraws_ = 0;
  bool sceneShot_ = false;
  std::map<std::string, Permutation> permutations_;
  std::map<IDirect3DVertexDeclaration9*, DeclInfo> decls_;
  std::map<IDirect3DBaseTexture9*, int> textures_;
  std::set<uint32_t> savedShaders_;
};
