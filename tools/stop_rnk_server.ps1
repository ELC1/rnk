$processes = Get-Process srcds -ErrorAction SilentlyContinue

if (!$processes) {
    Write-Host "Nenhum processo srcds.exe em execucao."
    exit 0
}

$processes | Stop-Process -Force
Write-Host "Servidor RNK finalizado."
