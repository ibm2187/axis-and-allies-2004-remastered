#pragma once
#include "Common.h"

// Readable names for the Direct3D 9 enums that show up in frame captures.
const char* FormatName(D3DFORMAT format);
const char* TextureOpName(DWORD op);
std::string TextureArgName(DWORD arg);
const char* DeclTypeName(BYTE type);
const char* DeclUsageName(BYTE usage);
const char* BlendName(DWORD blend);
const char* TransformName(D3DTRANSFORMSTATETYPE state);
const char* RenderStateName(D3DRENDERSTATETYPE state);  // nullptr for states the capture doesn't print by name
