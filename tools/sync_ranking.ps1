$JsonPath  = "d:\RNK\runtime\css\cstrike\addons\sourcemod\data\rnk_export.json"
$ApiUrl    = "https://api.rnk.lat/sync"
$ApiSecret = "troque_por_chave_secreta"   # mesmo valor de API_SECRET no Railway
$Interval  = 60   # segundos entre cada sync

Write-Host "[RNK Sync] Iniciado. Monitorando $JsonPath a cada $Interval segundos."

$lastModified = [datetime]::MinValue

while ($true) {
    Start-Sleep -Seconds $Interval

    if (-not (Test-Path $JsonPath)) {
        continue
    }

    $modified = (Get-Item $JsonPath).LastWriteTime
    if ($modified -le $lastModified) {
        continue
    }

    try {
        $body    = Get-Content $JsonPath -Raw -Encoding UTF8
        $headers = @{ "Content-Type" = "application/json"; "x-api-key" = $ApiSecret }
        $resp    = Invoke-RestMethod -Uri $ApiUrl -Method Post -Body $body -Headers $headers -TimeoutSec 10
        Write-Host "[RNK Sync] $(Get-Date -Format 'HH:mm:ss') OK — $($resp.count) jogadores sincronizados."
        $lastModified = $modified
    } catch {
        Write-Host "[RNK Sync] $(Get-Date -Format 'HH:mm:ss') ERRO: $_"
    }
}
