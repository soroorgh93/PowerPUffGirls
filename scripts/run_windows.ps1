param([string]$Profile = "", [int]$Port = 8600, [string]$OllamaModel = "", [switch]$Web)
# Start EdgeGuardian from PowerShell (shows the logs). Desktop mode by default; -Web serves the
# browser UI at http://127.0.0.1:<Port> instead. EdgeGuardian.exe does the same without a console.
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
if (-not $Profile) { $Profile = if (Test-Path "profile.txt") { (Get-Content "profile.txt" -Raw).Trim() } else { "pc_cpu" } }
if ($OllamaModel) { $env:GUARDIAN_LLM__MODEL = $OllamaModel }
if ($Web) {
    Write-Host "EdgeGuardian UI -> http://127.0.0.1:$Port  (profile $Profile)" -ForegroundColor Green
    & .\.venv-win\Scripts\python.exe -m edge_guardian serve --profile $Profile --port $Port
} else {
    Write-Host "EdgeGuardian desktop app (profile $Profile) - close the window to quit" -ForegroundColor Green
    & .\.venv-win\Scripts\python.exe -m edge_guardian desktop --profile $Profile --port $Port
}
