#include "Common.h"

#include <cstdarg>
#include <cstdio>
#include <mutex>

extern "C" IMAGE_DOS_HEADER __ImageBase;

const std::wstring& ModuleDir() {
  static const std::wstring dir = [] {
    wchar_t path[MAX_PATH];
    DWORD n = GetModuleFileNameW(reinterpret_cast<HMODULE>(&__ImageBase), path, MAX_PATH);
    std::wstring s(path, n);
    return s.substr(0, s.find_last_of(L"\\/") + 1);
  }();
  return dir;
}

const Config& GetConfig() {
  static const Config config = [] {
    Config c;
    std::wstring ini = ModuleDir() + L"AALight.ini";
    wchar_t buffer[MAX_PATH];
    GetPrivateProfileStringW(L"AALight", L"RealD3D9", c.realD3D9.c_str(), buffer, MAX_PATH, ini.c_str());
    c.realD3D9 = buffer;
    c.logLights = GetPrivateProfileIntW(L"AALight", L"LogLights", c.logLights, ini.c_str()) != 0;
    c.autoCaptureLitFrames = GetPrivateProfileIntW(L"AALight", L"AutoCaptureLitFrames", c.autoCaptureLitFrames, ini.c_str());
    c.captureFrame = GetPrivateProfileIntW(L"AALight", L"CaptureFrame", c.captureFrame, ini.c_str());
    return c;
  }();
  return config;
}

namespace {
std::mutex logMutex;
FILE* logFile = nullptr;
}  // namespace

void Log(const char* format, ...) {
  std::lock_guard<std::mutex> lock(logMutex);
  if (!logFile) {
    logFile = _wfsopen((ModuleDir() + L"AALight.log").c_str(), L"w", _SH_DENYWR);
    if (!logFile) return;
  }
  SYSTEMTIME t;
  GetLocalTime(&t);
  fprintf(logFile, "%02d:%02d:%02d.%03d ", t.wHour, t.wMinute, t.wSecond, t.wMilliseconds);
  va_list args;
  va_start(args, format);
  vfprintf(logFile, format, args);
  va_end(args);
  fputc('\n', logFile);
}

void LogFlush() {
  std::lock_guard<std::mutex> lock(logMutex);
  if (logFile) fflush(logFile);
}

uint32_t Fnv1a(const void* data, size_t size, uint32_t hash) {
  auto bytes = static_cast<const uint8_t*>(data);
  for (size_t i = 0; i < size; ++i) hash = (hash ^ bytes[i]) * 16777619u;
  return hash;
}
