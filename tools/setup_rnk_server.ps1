param(
    [string]$InstallRoot = (Join-Path (Split-Path -Parent $PSScriptRoot) "runtime"),
    [string]$SteamCmdUrl = "https://steamcdn-a.akamaihd.net/client/installer/steamcmd.zip",
    [string]$CssServerAppId = "232330",
    [string]$CssServerBranch = "prerelease",
    [string]$MetaModUrl = "https://github.com/alliedmodders/metamod-source/releases/download/1.12.0.1221/mmsource-1.12.0-git1221-windows.zip",
    [string]$SourceModUrl = "https://github.com/alliedmodders/sourcemod/releases/download/1.12.0.7228/sourcemod-1.12.0-git7228-windows.zip"
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$steamCmdRoot = Join-Path $InstallRoot "steamcmd"
$cssRoot = Join-Path $InstallRoot "css"
$gameRoot = Join-Path $cssRoot "cstrike"
$downloadsRoot = Join-Path $InstallRoot "downloads"

foreach ($path in @($InstallRoot, $steamCmdRoot, $cssRoot, $downloadsRoot)) {
    if (!(Test-Path $path)) {
        New-Item -ItemType Directory -Path $path | Out-Null
    }
}

$steamCmdZip = Join-Path $downloadsRoot "steamcmd.zip"
$metaModZip = Join-Path $downloadsRoot "metamod.zip"
$sourceModZip = Join-Path $downloadsRoot "sourcemod.zip"

Write-Host "Baixando SteamCMD..."
Invoke-WebRequest -Uri $SteamCmdUrl -OutFile $steamCmdZip
Expand-Archive -Path $steamCmdZip -DestinationPath $steamCmdRoot -Force

$steamCmdExe = Join-Path $steamCmdRoot "steamcmd.exe"
if (!(Test-Path $steamCmdExe)) {
    throw "steamcmd.exe nao foi encontrado apos a extracao."
}

Write-Host "Instalando Counter-Strike: Source Dedicated Server..."
& $steamCmdExe +force_install_dir $cssRoot +login anonymous +app_update "$CssServerAppId -beta $CssServerBranch" validate +quit
if (!(Test-Path (Join-Path $cssRoot "srcds.exe"))) {
    throw "Falha ao instalar o servidor dedicado do Counter-Strike: Source."
}

Write-Host "Baixando MetaMod:Source..."
Invoke-WebRequest -Uri $MetaModUrl -OutFile $metaModZip
Expand-Archive -Path $metaModZip -DestinationPath $gameRoot -Force

Write-Host "Baixando SourceMod..."
Invoke-WebRequest -Uri $SourceModUrl -OutFile $sourceModZip
Expand-Archive -Path $sourceModZip -DestinationPath $gameRoot -Force

$metamodVdfDir = Join-Path $gameRoot "addons"
if (!(Test-Path $metamodVdfDir)) {
    New-Item -ItemType Directory -Path $metamodVdfDir | Out-Null
}

$metamodVdf = @'
"Plugin"
{
    "file"    "../cstrike/addons/metamod/bin/server"
}
'@

Set-Content -LiteralPath (Join-Path $metamodVdfDir "metamod.vdf") -Value $metamodVdf -Encoding ASCII

Write-Host "Copiando configuracoes do projeto RNK..."
Copy-Item -Path (Join-Path $projectRoot "server\*") -Destination $cssRoot -Recurse -Force

$pluginDir = Join-Path $gameRoot "addons\sourcemod\plugins"
if (!(Test-Path $pluginDir)) {
    New-Item -ItemType Directory -Path $pluginDir | Out-Null
}

Get-ChildItem -Path $pluginDir -Filter *.smx -ErrorAction SilentlyContinue | Remove-Item -Force

$spcompExe = Join-Path $gameRoot "addons\sourcemod\scripting\spcomp.exe"

if (!(Test-Path $spcompExe)) {
    throw "spcomp.exe nao foi encontrado apos a instalacao do SourceMod."
}

Write-Host "Compilando plugins proprios RNK..."
Get-ChildItem -Path (Join-Path $gameRoot "addons\sourcemod\scripting") -Filter "rnk_*.sp" | ForEach-Object {
    $pluginName = [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
    $pluginOutput = Join-Path $pluginDir "$pluginName.smx"

    & $spcompExe $_.FullName "-o$pluginOutput"
    if ($LASTEXITCODE -ne 0 -or !(Test-Path $pluginOutput)) {
        throw "Falha ao compilar o plugin proprio $pluginName."
    }
}

Write-Host "Setup concluido em $cssRoot"
