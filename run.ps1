$ErrorActionPreference = "Stop"

$root = $PSScriptRoot
$backend = Join-Path $root "backend"
$frontend = Join-Path $root "frontend"
$venvPython = Join-Path $backend ".venv\Scripts\python.exe"

function Test-HttpService([string]$Url) {
    try {
        $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
        return $response.StatusCode -eq 200
    } catch {
        return $false
    }
}

function Test-ListeningPort([int]$Port) {
    return [bool](Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1)
}

if (-not (Test-Path $venvPython)) {
    $pythonLauncher = Get-Command py.exe -ErrorAction SilentlyContinue
    if (-not $pythonLauncher) {
        throw "Python and the Windows 'py' launcher are required."
    }

    & $pythonLauncher.Source -m venv (Join-Path $backend ".venv")
    if ($LASTEXITCODE -ne 0) {
        throw "Could not create the backend virtual environment."
    }
}

& $venvPython -m pip install -r (Join-Path $backend "requirements-dev.txt")
if ($LASTEXITCODE -ne 0) {
    throw "Could not install backend dependencies."
}

$portableNode = Join-Path $env:TEMP "lexsutra-node-portable\node-v22.23.3-win-x64"
if ((Test-Path (Join-Path $portableNode "node.exe")) -and (Test-Path (Join-Path $portableNode "npm.cmd"))) {
    $env:Path = "$portableNode;$env:Path"
    $npm = Join-Path $portableNode "npm.cmd"
} else {
    $nodeCommand = Get-Command node.exe -ErrorAction SilentlyContinue
    $npmCommand = Get-Command npm.cmd -ErrorAction SilentlyContinue
    if (-not $nodeCommand -or -not $npmCommand) {
        throw "Install Node.js 20.9 or newer, then run this command again."
    }
    $npm = $npmCommand.Source
}

if (-not (Test-Path (Join-Path $frontend "node_modules"))) {
    Push-Location $frontend
    try {
        & $npm install
        if ($LASTEXITCODE -ne 0) {
            throw "Could not install frontend dependencies."
        }
    } finally {
        Pop-Location
    }
}

$apiCommand = '/k "{0}" -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8000' -f $venvPython
$webCommand = '/k "{0}" run dev -- --hostname 127.0.0.1' -f $npm

if (Test-HttpService "http://127.0.0.1:8000/health") {
    Write-Host "API is already running."
} elseif (Test-ListeningPort 8000) {
    throw "Port 8000 is occupied by another service. Stop it, then run this script again."
} else {
    Start-Process -FilePath $env:ComSpec -ArgumentList $apiCommand -WorkingDirectory $backend
}

if (Test-HttpService "http://127.0.0.1:3000/") {
    Write-Host "Web app is already running."
} elseif (Test-ListeningPort 3000) {
    throw "Port 3000 is occupied by another service. Stop it, then run this script again."
} else {
    Start-Process -FilePath $env:ComSpec -ArgumentList $webCommand -WorkingDirectory $frontend
}

Write-Host "API: http://127.0.0.1:8000"
Write-Host "Web app: http://127.0.0.1:3000"