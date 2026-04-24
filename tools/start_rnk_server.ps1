param(
    [string]$InstallRoot = (Join-Path (Split-Path -Parent $PSScriptRoot) "runtime"),
    [int]$MaxPlayers = 32,
    [int]$Port = 27015,
    [switch]$NoBots
)

$ErrorActionPreference = "Stop"

$cssRoot = Join-Path $InstallRoot "css"
$srcdsExe = Join-Path $cssRoot "srcds.exe"

if (!(Test-Path $srcdsExe)) {
    throw "srcds.exe nao encontrado em $srcdsExe. Rode primeiro tools/setup_rnk_server.ps1."
}

$arguments = @(
    "-game", "cstrike",
    "-console",
    "-usercon",
    "-insecure",
    "+sv_hibernate_when_empty", "0",
    "+map", "de_dust2",
    "+maxplayers", $MaxPlayers,
    "-port", $Port
)

if ($NoBots) {
    $arguments += @("+bot_quota", "0")
}

Start-Process -FilePath $srcdsExe -ArgumentList $arguments -WorkingDirectory $cssRoot
Write-Host "Servidor RNK iniciado em $cssRoot na porta $Port"
