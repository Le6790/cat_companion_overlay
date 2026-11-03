<#
.SYNOPSIS
  Builds dist\CatCompanionOverlay.exe (PyInstaller). Run from anywhere:  powershell -File windows\build_exe.ps1
.PARAMETER OneDir
  Build a folder (dist\CatCompanionOverlay\) instead of a single exe. Starts faster (no unpacking
  on every launch) and is less likely to trip antivirus heuristics.
#>
param([switch]$OneDir)
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

if (-not (Test-Path .venv)) { py -3 -m venv .venv }   # needs Python 3.10+ from python.org
$py = ".\.venv\Scripts\python.exe"
& $py -m pip install --quiet --upgrade pip
& $py -m pip install --quiet -r requirements.txt -r requirements-build.txt

$sprites = (Resolve-Path ..\Sources\CatCompanionOverlay\sprites).Path   # shared with the macOS app
$mode = if ($OneDir) { "--onedir" } else { "--onefile" }

& $py -m PyInstaller --noconfirm --clean $mode --windowed `
    --name CatCompanionOverlay `
    --add-data "$sprites;sprites" `
    main.py
if ($LASTEXITCODE -ne 0) { throw "PyInstaller failed" }

if ($OneDir) { Write-Host "Built dist\CatCompanionOverlay\CatCompanionOverlay.exe" }
else         { Write-Host "Built dist\CatCompanionOverlay.exe" }
