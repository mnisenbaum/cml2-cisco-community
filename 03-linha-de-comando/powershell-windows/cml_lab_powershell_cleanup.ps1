# Remove o lab de teste criado por cml_lab_powershell.ps1 (stop -> wipe -> delete).
# O CML2 nao deixa remover um lab que nao passou por wipe -- DELETE direto
# num lab so STOPPED da erro 400.

$ErrorActionPreference = "Stop"

if ($PSVersionTable.PSVersion.Major -lt 6) {
    Write-Error "Este script requer PowerShell 7+ (pwsh)."
    exit 1
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Resolve-Path (Join-Path $ScriptDir "..\..")
$EnvFile = Join-Path $RepoRoot ".env"

$LabTitle = if ($env:LAB_TITLE) { $env:LAB_TITLE } else { "teste-cli-powershell" }

$EnvVars = @{}
Get-Content $EnvFile | ForEach-Object {
    $line = $_.TrimEnd("`r")
    if ($line -match '^([^=]+)=(.*)$') {
        $EnvVars[$Matches[1]] = $Matches[2]
    }
}
$CmlUrl = $EnvVars["CML_URL"].TrimEnd('/')
$CmlUsername = $EnvVars["CML_USERNAME"]
$CmlPassword = $EnvVars["CML_PASSWORD"]
$BaseUrl = "$CmlUrl/api/v0"

$AuthBody = @{ username = $CmlUsername; password = $CmlPassword } | ConvertTo-Json
$Token = Invoke-RestMethod -SkipCertificateCheck -Method Post -Uri "$BaseUrl/authenticate" -ContentType "application/json" -Body $AuthBody
$Headers = @{ Authorization = "Bearer $Token" }

$Labs = Invoke-RestMethod -SkipCertificateCheck -Method Get -Uri "$BaseUrl/labs?show_all=true&with_data=true" -Headers $Headers
$Lab = $Labs | Where-Object { $_.lab_title -eq $LabTitle } | Select-Object -First 1
if (-not $Lab) {
    Write-Error "Nenhum lab '$LabTitle' encontrado."
    exit 1
}
$LabId = $Lab.id

Write-Host "==> Removendo lab '$LabTitle' (id=$LabId)..."
Invoke-RestMethod -SkipCertificateCheck -Method Put -Uri "$BaseUrl/labs/$LabId/stop" -Headers $Headers | Out-Null
Write-Host "    stop OK"
Invoke-RestMethod -SkipCertificateCheck -Method Put -Uri "$BaseUrl/labs/$LabId/wipe" -Headers $Headers | Out-Null
Write-Host "    wipe OK"
Invoke-RestMethod -SkipCertificateCheck -Method Delete -Uri "$BaseUrl/labs/$LabId" -Headers $Headers | Out-Null
Write-Host "    delete OK"
Write-Host "==> Concluido."
