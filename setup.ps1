Set-Location $PSScriptRoot

if (-not (Test-Path ".venv")) {
    & python -m venv .venv
}

$pythonExe = Join-Path $PSScriptRoot ".venv\Scripts\python.exe"
& $pythonExe -m pip install --upgrade pip
& $pythonExe -m pip install -r requirements.txt
& $pythonExe -m unidic download

$checkpointUrl = "https://myshell-public-repo-host.s3.amazonaws.com/openvoice/checkpoints_v2_0417.zip"
$checkpointZip = Join-Path $PSScriptRoot "checkpoints_v2_0417.zip"

Invoke-WebRequest -Uri $checkpointUrl -OutFile $checkpointZip
Expand-Archive -Path $checkpointZip -DestinationPath $PSScriptRoot -Force
Remove-Item $checkpointZip

Write-Host "Setup complete. Open speech_2_speech.ipynb and run all cells."