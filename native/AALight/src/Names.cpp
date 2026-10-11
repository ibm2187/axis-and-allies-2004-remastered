#include "Names.h"

const char* FormatName(D3DFORMAT format) {
  switch (format) {
    case D3DFMT_A8R8G8B8: return "A8R8G8B8";
    case D3DFMT_X8R8G8B8: return "X8R8G8B8";
    case D3DFMT_R5G6B5: return "R5G6B5";
    case D3DFMT_X1R5G5B5: return "X1R5G5B5";
    case D3DFMT_A1R5G5B5: return "A1R5G5B5";
    case D3DFMT_A4R4G4B4: return "A4R4G4B4";
    case D3DFMT_A8: return "A8";
    case D3DFMT_L8: return "L8";
    case D3DFMT_A8L8: return "A8L8";
    case D3DFMT_A16B16G16R16F: return "A16B16G16R16F";
    case D3DFMT_R32F: return "R32F";
    case D3DFMT_DXT1: return "DXT1";
    case D3DFMT_DXT2: return "DXT2";
    case D3DFMT_DXT3: return "DXT3";
    case D3DFMT_DXT4: return "DXT4";
    case D3DFMT_DXT5: return "DXT5";
    case D3DFMT_D16: return "D16";
    case D3DFMT_D24S8: return "D24S8";
    case D3DFMT_D24X8: return "D24X8";
    case D3DFMT_D32: return "D32";
    case D3DFMT_UNKNOWN: return "UNKNOWN";
    default: return "?";
  }
}

const char* TextureOpName(DWORD op) {
  static const char* names[] = {"?", "DISABLE", "SELECTARG1", "SELECTARG2", "MODULATE", "MODULATE2X",
                                "MODULATE4X", "ADD", "ADDSIGNED", "ADDSIGNED2X", "SUBTRACT", "ADDSMOOTH",
                                "BLENDDIFFUSEALPHA", "BLENDTEXTUREALPHA", "BLENDFACTORALPHA",
                                "BLENDTEXTUREALPHAPM", "BLENDCURRENTALPHA", "PREMODULATE",
                                "MODULATEALPHA_ADDCOLOR", "MODULATECOLOR_ADDALPHA",
                                "MODULATEINVALPHA_ADDCOLOR", "MODULATEINVCOLOR_ADDALPHA", "BUMPENVMAP",
                                "BUMPENVMAPLUMINANCE", "DOTPRODUCT3", "MULTIPLYADD", "LERP"};
  return op < sizeof(names) / sizeof(*names) ? names[op] : "?";
}

std::string TextureArgName(DWORD arg) {
  static const char* names[] = {"DIFFUSE", "CURRENT", "TEXTURE", "TFACTOR", "SPECULAR", "TEMP", "CONSTANT"};
  std::string s = (arg & D3DTA_SELECTMASK) < 7 ? names[arg & D3DTA_SELECTMASK] : "?";
  if (arg & D3DTA_COMPLEMENT) s = "1-" + s;
  if (arg & D3DTA_ALPHAREPLICATE) s += ".a";
  return s;
}

const char* DeclTypeName(BYTE type) {
  static const char* names[] = {"FLOAT1", "FLOAT2", "FLOAT3", "FLOAT4", "D3DCOLOR", "UBYTE4", "SHORT2",
                                "SHORT4", "UBYTE4N", "SHORT2N", "SHORT4N", "USHORT2N", "USHORT4N",
                                "UDEC3", "DEC3N", "FLOAT16_2", "FLOAT16_4"};
  return type < sizeof(names) / sizeof(*names) ? names[type] : "UNUSED";
}

const char* DeclUsageName(BYTE usage) {
  static const char* names[] = {"POSITION", "BLENDWEIGHT", "BLENDINDICES", "NORMAL", "PSIZE", "TEXCOORD",
                                "TANGENT", "BINORMAL", "TESSFACTOR", "POSITIONT", "COLOR", "FOG", "DEPTH",
                                "SAMPLE"};
  return usage < sizeof(names) / sizeof(*names) ? names[usage] : "?";
}

const char* BlendName(DWORD blend) {
  static const char* names[] = {"?", "ZERO", "ONE", "SRCCOLOR", "INVSRCCOLOR", "SRCALPHA", "INVSRCALPHA",
                                "DESTALPHA", "INVDESTALPHA", "DESTCOLOR", "INVDESTCOLOR", "SRCALPHASAT",
                                "BOTHSRCALPHA", "BOTHINVSRCALPHA", "BLENDFACTOR", "INVBLENDFACTOR"};
  return blend < sizeof(names) / sizeof(*names) ? names[blend] : "?";
}

const char* TransformName(D3DTRANSFORMSTATETYPE state) {
  switch (static_cast<DWORD>(state)) {
    case D3DTS_VIEW: return "VIEW";
    case D3DTS_PROJECTION: return "PROJECTION";
    case D3DTS_WORLD: return "WORLD";
    case D3DTS_TEXTURE0: return "TEXTURE0";
    case D3DTS_TEXTURE1: return "TEXTURE1";
    case D3DTS_TEXTURE2: return "TEXTURE2";
    case D3DTS_TEXTURE3: return "TEXTURE3";
    default: return "?";
  }
}

const char* RenderStateName(D3DRENDERSTATETYPE state) {
  switch (state) {
    case D3DRS_ZENABLE: return "ZENABLE";
    case D3DRS_FILLMODE: return "FILLMODE";
    case D3DRS_SHADEMODE: return "SHADEMODE";
    case D3DRS_ZWRITEENABLE: return "ZWRITEENABLE";
    case D3DRS_ALPHATESTENABLE: return "ALPHATESTENABLE";
    case D3DRS_SRCBLEND: return "SRCBLEND";
    case D3DRS_DESTBLEND: return "DESTBLEND";
    case D3DRS_CULLMODE: return "CULLMODE";
    case D3DRS_ZFUNC: return "ZFUNC";
    case D3DRS_ALPHAREF: return "ALPHAREF";
    case D3DRS_ALPHAFUNC: return "ALPHAFUNC";
    case D3DRS_ALPHABLENDENABLE: return "ALPHABLENDENABLE";
    case D3DRS_FOGENABLE: return "FOGENABLE";
    case D3DRS_SPECULARENABLE: return "SPECULARENABLE";
    case D3DRS_FOGCOLOR: return "FOGCOLOR";
    case D3DRS_FOGTABLEMODE: return "FOGTABLEMODE";
    case D3DRS_FOGSTART: return "FOGSTART";
    case D3DRS_FOGEND: return "FOGEND";
    case D3DRS_FOGDENSITY: return "FOGDENSITY";
    case D3DRS_STENCILENABLE: return "STENCILENABLE";
    case D3DRS_STENCILFUNC: return "STENCILFUNC";
    case D3DRS_STENCILPASS: return "STENCILPASS";
    case D3DRS_TEXTUREFACTOR: return "TEXTUREFACTOR";
    case D3DRS_LIGHTING: return "LIGHTING";
    case D3DRS_AMBIENT: return "AMBIENT";
    case D3DRS_FOGVERTEXMODE: return "FOGVERTEXMODE";
    case D3DRS_COLORVERTEX: return "COLORVERTEX";
    case D3DRS_LOCALVIEWER: return "LOCALVIEWER";
    case D3DRS_NORMALIZENORMALS: return "NORMALIZENORMALS";
    case D3DRS_DIFFUSEMATERIALSOURCE: return "DIFFUSEMATERIALSOURCE";
    case D3DRS_SPECULARMATERIALSOURCE: return "SPECULARMATERIALSOURCE";
    case D3DRS_AMBIENTMATERIALSOURCE: return "AMBIENTMATERIALSOURCE";
    case D3DRS_EMISSIVEMATERIALSOURCE: return "EMISSIVEMATERIALSOURCE";
    case D3DRS_VERTEXBLEND: return "VERTEXBLEND";
    case D3DRS_COLORWRITEENABLE: return "COLORWRITEENABLE";
    case D3DRS_BLENDOP: return "BLENDOP";
    case D3DRS_TWOSIDEDSTENCILMODE: return "TWOSIDEDSTENCILMODE";
    case D3DRS_DEPTHBIAS: return "DEPTHBIAS";
    case D3DRS_SLOPESCALEDEPTHBIAS: return "SLOPESCALEDEPTHBIAS";
    case D3DRS_SRGBWRITEENABLE: return "SRGBWRITEENABLE";
    case D3DRS_MULTISAMPLEANTIALIAS: return "MULTISAMPLEANTIALIAS";
    default: return nullptr;
  }
}
