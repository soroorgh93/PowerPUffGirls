<#
EdgeGuardian - Windows PC setup (test rig). Run from the project root in PowerShell:

    Set-ExecutionPolicy -Scope Process Bypass
    .\scripts\setup_windows.ps1                 # CPU (default)
    .\scripts\setup_windows.ps1 -Compute CUDA   # NVIDIA GPU (uses the cu124 wheel index)
    .\scripts\setup_windows.ps1 -SkipModels     # environment only
    .\scripts\setup_windows.ps1 -SkipDemoClips  # do not download the public example recordings

Creates .venv-win, installs the stack, downloads the models, pulls the Ollama model, fetches the
REAL public example recordings (data\demo), builds EdgeGuardian.exe (native launcher) + a Desktop shortcut,
runs the tests and prints how to start the app. Ollama must be installed separately:
https://ollama.com/download (it listens on :11434). Everything runs locally after setup.
#>
param(
    [ValidateSet("CPU", "CUDA")] [string]$Compute = "CPU",
    [string]$TorchIndexUrl = "https://download.pytorch.org/whl/cu124",
    [string]$OllamaModel = "qwen3.5:4b",
    [switch]$SkipModels,
    [switch]$SkipDemoClips,
    [switch]$SkipTests
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
Write-Host "== EdgeGuardian setup ($Compute) in $root" -ForegroundColor Cyan

$py = Get-Command python -ErrorAction SilentlyContinue
if (-not $py) { throw "python not found. Install Python 3.10-3.12 (or use Anaconda: conda create -n guardian python=3.11)." }
if (-not (Test-Path ".venv-win")) { python -m venv .venv-win }
$venvPy = ".\.venv-win\Scripts\python.exe"
& $venvPy -m pip install --upgrade pip setuptools wheel | Out-Null

Write-Host "-- core requirements"
& $venvPy -m pip install -r requirements\base.txt
Write-Host "-- torch ($Compute)"
if ($Compute -eq "CUDA") {
    & $venvPy -m pip install torch torchvision torchaudio --index-url $TorchIndexUrl
} else {
    & $venvPy -m pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
}
Write-Host "-- vision + audio + desktop requirements"
& $venvPy -m pip install -r requirements\vision.txt -r requirements\audio.txt -r requirements\desktop.txt
& $venvPy -m pip install -e . --no-deps
Write-Host "-- TTS for the multilingual voicemail demo clips (edge-tts; generation only)"
& $venvPy -m pip install -r requirements\tts.txt
if ($LASTEXITCODE -ne 0) { Write-Warning "TTS packages not installed; voicemail demo clips will be skipped (everything else works)" }

if (-not $SkipModels) {
    Write-Host "-- pretrained models (YOLO11n, YOLO11n-pose, gun/knife, fallen, whisper, detoxify, CLAP, CLIP)"
    & $venvPy scripts\download_models.py --asr small
    if (Get-Command ollama -ErrorAction SilentlyContinue) {
        Write-Host "-- ollama pull $OllamaModel (vision + JSON reasoning)"
        ollama pull $OllamaModel
    } else {
        Write-Warning "ollama not found: install from https://ollama.com/download then run: ollama pull $OllamaModel"
    }
}

if (-not $SkipDemoClips) {
    Write-Host "-- public example recordings (falls, weapons, fights, baby, voicemail) -> data\demo"
    try { & $venvPy scripts\fetch_real_demo_clips.py --out data\demo } catch { Write-Warning "demo clips: $_" }
}

if (-not $SkipTests) {
    Write-Host "-- tests (fixture profile, no models needed; test clips are generated under tests\.fixtures)"
    & $venvPy -m pytest -q
}

# ---- native launcher: EdgeGuardian.exe (compiled with the C# compiler that ships with Windows)
$profile = if ($Compute -eq "CUDA") { "pc_gpu" } else { "pc_cpu" }
Set-Content -Path "profile.txt" -Value $profile -Encoding ascii
$csc = Join-Path $env:WINDIR "Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if (-not (Test-Path $csc)) { $csc = Join-Path $env:WINDIR "Microsoft.NET\Framework\v4.0.30319\csc.exe" }
if (Test-Path $csc) {
    Write-Host "-- building EdgeGuardian.exe"
    & $csc /nologo /target:winexe /out:EdgeGuardian.exe /win32icon:installer\sentinel.ico /r:System.Windows.Forms.dll installer\EdgeGuardian.cs
    if (Test-Path "EdgeGuardian.exe") {
        $shell = New-Object -ComObject WScript.Shell
        foreach ($dir in @([Environment]::GetFolderPath("Desktop"), (Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs"))) {
            $lnk = $shell.CreateShortcut((Join-Path $dir "EdgeGuardian.lnk"))
            $lnk.TargetPath = (Join-Path $root "EdgeGuardian.exe")
            $lnk.WorkingDirectory = $root
            $lnk.IconLocation = (Join-Path $root "installer\sentinel.ico")
            $lnk.Description = "EdgeGuardian - on-device multimodal safety investigator"
            $lnk.Save()
        }
        Write-Host "   EdgeGuardian.exe built; shortcuts placed on the Desktop and in the Start Menu." -ForegroundColor Green
    }
} else {
    Write-Warning "C# compiler not found; use .\scripts\run_windows.ps1 instead of EdgeGuardian.exe"
}

Write-Host ""
Write-Host "Setup complete." -ForegroundColor Green
Write-Host "   Double-click EdgeGuardian.exe (or the Desktop shortcut)   # desktop app, profile $profile"
Write-Host "   .\scripts\run_windows.ps1 -Profile $profile                 # same, from PowerShell (shows logs)"
Write-Host "   .\scripts\run_windows.ps1 -Profile fixture                # rehearsal mode, no models"
