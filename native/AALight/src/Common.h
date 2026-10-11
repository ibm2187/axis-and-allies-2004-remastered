#pragma once
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#include <d3d9.h>

#include <cstdint>
#include <string>

// Folder that holds AALight's D3D9.dll (the game folder), with a trailing backslash.
const std::wstring& ModuleDir();

// AALight.ini next to the DLL, section [AALight].
struct Config {
  std::wstring realD3D9 = L"D3D9.dgVoodoo.dll";  // relative to ModuleDir() or absolute
  bool logLights = true;                          // log every change of a fixed-function light
  int autoCaptureLitFrames = 300;                 // capture once after this many frames with 50+ lit draws (0 = off)
  int captureFrame = 0;                           // capture this frame number (0 = off; for tests)
};
const Config& GetConfig();

void Log(const char* format, ...);
void LogFlush();

uint32_t Fnv1a(const void* data, size_t size, uint32_t hash = 2166136261u);
