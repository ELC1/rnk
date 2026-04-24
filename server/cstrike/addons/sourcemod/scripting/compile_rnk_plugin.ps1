param(
    [string]$SourcePawnCompiler = "spcomp.exe"
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$outputDir = Join-Path (Split-Path $scriptDir -Parent) "plugins"

if (!(Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

Get-ChildItem -Path $scriptDir -Filter "rnk_*.sp" | ForEach-Object {
    $pluginSource = $_.FullName
    $pluginName = [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
    $pluginOutput = Join-Path $outputDir "$pluginName.smx"

    & $SourcePawnCompiler $pluginSource "-o$pluginOutput"
    if ($LASTEXITCODE -ne 0) {
        throw "Falha ao compilar o plugin $pluginName."
    }
}

Write-Host "Plugins RNK compilados com sucesso em $outputDir"
