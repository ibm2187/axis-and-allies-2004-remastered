@echo off
rem Builds AALight's D3D9.dll (32-bit) and the smoke test into native\AALight\build\.
rem Needs Visual Studio 2022 or later with the C++ desktop workload (x86 tools) and a Windows SDK.
setlocal
set ROOT=%~dp0
set VS=
pushd "%ProgramFiles(x86)%\Microsoft Visual Studio\Installer"
for /f "usebackq delims=" %%i in (`.\vswhere.exe -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do set VS=%%i
popd
if not defined VS (echo Visual Studio with C++ tools not found & exit /b 1)
call "%VS%\VC\Auxiliary\Build\vcvars32.bat" >nul || exit /b 1
if not exist "%ROOT%build" mkdir "%ROOT%build"
cd /d "%ROOT%build"
set FLAGS=/nologo /O2 /MT /std:c++17 /EHsc /W4 /permissive- /DUNICODE /D_UNICODE /D_CRT_SECURE_NO_WARNINGS /I"%ROOT%src"
cl %FLAGS% /LD /FeD3D9.dll "%ROOT%src\*.cpp" /link /DEF:"%ROOT%src\AALight.def" user32.lib || exit /b 1
cl %FLAGS% /FeSmokeTest.exe "%ROOT%test\SmokeTest.cpp" /link user32.lib || exit /b 1
echo Built %ROOT%build\D3D9.dll
