# Cria a topologia de referencia (losango OSPF, 4 roteadores iol-xe) no CML2
# via API REST, usando PowerShell puro (Invoke-RestMethod) -- sem WSL.
#
# Le CML_URL / CML_USERNAME / CML_PASSWORD de .env na raiz do repositorio.
# Nao remove o lab ao final -- confira a convergencia OSPF manualmente no
# console/GUI antes de rodar cml_lab_powershell_cleanup.ps1.

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Resolve-Path (Join-Path $ScriptDir "..\..")
$ConfigDir = Join-Path $RepoRoot "01-manual\respostas-configuracao"
$EnvFile = Join-Path $RepoRoot ".env"

$LabTitle = if ($env:LAB_TITLE) { $env:LAB_TITLE } else { "teste-cli-powershell" }

# .env pode ter sido salvo com CRLF -- Get-Content ja trata isso linha a linha,
# mas removemos \r explicitamente por seguranca (caso venha tudo numa linha so).
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

# Certificado do controller e autoassinado -- requer PowerShell 7+ (Core),
# que tem -SkipCertificateCheck nativo em Invoke-RestMethod. Nao funciona no
# Windows PowerShell 5.1 (nesse caso, usar o -UseBasicParsing + bypass
# separado, ou rodar via WSL/trilha bash).
if ($PSVersionTable.PSVersion.Major -lt 6) {
    Write-Error "Este script requer PowerShell 7+ (pwsh). Voce esta rodando Windows PowerShell $($PSVersionTable.PSVersion) -- abra o 'PowerShell 7' em vez do 'Windows PowerShell'."
    exit 1
}

Write-Host "==> Autenticando em $BaseUrl ..."
$AuthBody = @{ username = $CmlUsername; password = $CmlPassword } | ConvertTo-Json
$Token = Invoke-RestMethod -SkipCertificateCheck -Method Post -Uri "$BaseUrl/authenticate" -ContentType "application/json" -Body $AuthBody
$Headers = @{ Authorization = "Bearer $Token" }
Write-Host "    OK"

Write-Host "==> Checando se ja existe um lab '$LabTitle'..."
$ExistingLabs = Invoke-RestMethod -SkipCertificateCheck -Method Get -Uri "$BaseUrl/labs?show_all=true&with_data=true" -Headers $Headers
$Existing = $ExistingLabs | Where-Object { $_.lab_title -eq $LabTitle }
if ($Existing) {
    Write-Error "Ja existe lab '$LabTitle' (id=$($Existing.id)). Remova antes de rodar de novo."
    exit 1
}
Write-Host "    OK, nenhum lab de teste pre-existente"

Write-Host "==> Criando lab '$LabTitle'..."
$LabBody = @{
    title       = $LabTitle
    description = "Lab de teste da Etapa 3 (linha de comando, trilha PowerShell) -- remover apos confirmacao."
} | ConvertTo-Json
$LabId = (Invoke-RestMethod -SkipCertificateCheck -Method Post -Uri "$BaseUrl/labs" -Headers $Headers -ContentType "application/json" -Body $LabBody).id
Write-Host "    lab_id = $LabId"

$Nodes = @(
    @{ Label = "R1"; X = -440; Y = -120 }
    @{ Label = "R2"; X = -240; Y = -320 }
    @{ Label = "R3"; X = -40;  Y = -120 }
    @{ Label = "R4"; X = -240; Y = 80 }
)

Write-Host "==> Criando os 4 nos (iol-xe) com as configs do gabarito..."
$NodeId = @{}
foreach ($Node in $Nodes) {
    $ConfigText = Get-Content -Raw (Join-Path $ConfigDir "$($Node.Label).txt")
    $Body = @{
        label            = $Node.Label
        node_definition  = "iol-xe"
        x                = $Node.X
        y                = $Node.Y
        configuration    = $ConfigText
    } | ConvertTo-Json
    $Id = (Invoke-RestMethod -SkipCertificateCheck -Method Post -Uri "$BaseUrl/labs/$LabId/nodes?populate_interfaces=true" -Headers $Headers -ContentType "application/json" -Body $Body).id
    $NodeId[$Node.Label] = $Id
    Write-Host "    $($Node.Label) -> node_id=$Id"
}

Write-Host "==> Lendo interfaces de cada no para mapear nome -> UUID..."
$Iface = @{}
foreach ($Node in $Nodes) {
    $Interfaces = Invoke-RestMethod -SkipCertificateCheck -Method Get -Uri "$BaseUrl/labs/$LabId/nodes/$($NodeId[$Node.Label])/interfaces?data=true&operational=false" -Headers $Headers
    $Eth00 = ($Interfaces | Where-Object { $_.label -eq "Ethernet0/0" }).id
    $Eth01 = ($Interfaces | Where-Object { $_.label -eq "Ethernet0/1" }).id
    $Iface["$($Node.Label)_Ethernet0/0"] = $Eth00
    $Iface["$($Node.Label)_Ethernet0/1"] = $Eth01
    Write-Host "    $($Node.Label): Eth0/0=$Eth00 Eth0/1=$Eth01"
}

function New-CmlLink($NodeA, $IfA, $NodeB, $IfB) {
    $Body = @{
        src_int = $Iface["${NodeA}_$IfA"]
        dst_int = $Iface["${NodeB}_$IfB"]
    } | ConvertTo-Json
    $LinkId = (Invoke-RestMethod -SkipCertificateCheck -Method Post -Uri "$BaseUrl/labs/$LabId/links" -Headers $Headers -ContentType "application/json" -Body $Body).id
    Write-Host "    ${NodeA}:${IfA} <-> ${NodeB}:${IfB} -> link_id=$LinkId"
}

Write-Host "==> Criando os 4 links do losango..."
New-CmlLink "R1" "Ethernet0/0" "R2" "Ethernet0/0"
New-CmlLink "R2" "Ethernet0/1" "R3" "Ethernet0/1"
New-CmlLink "R3" "Ethernet0/0" "R4" "Ethernet0/0"
New-CmlLink "R4" "Ethernet0/1" "R1" "Ethernet0/1"

Write-Host "==> Iniciando o lab..."
Invoke-RestMethod -SkipCertificateCheck -Method Put -Uri "$BaseUrl/labs/$LabId/start" -Headers $Headers | Out-Null
Write-Host "    disparado"

Write-Host "==> Aguardando todos os nos ficarem STARTED (polling a cada 5s, timeout 300s)..."
$Deadline = (Get-Date).AddSeconds(300)
while ((Get-Date) -lt $Deadline) {
    $State = Invoke-RestMethod -SkipCertificateCheck -Method Get -Uri "$BaseUrl/labs/$LabId/lab_element_state" -Headers $Headers
    $States = $State.nodes.PSObject.Properties | ForEach-Object { $_.Value }
    Write-Host "    $($State.nodes | ConvertTo-Json -Compress)"
    if (($States | Where-Object { $_ -ne "STARTED" }).Count -eq 0) {
        Write-Host "==> Todos os nos estao STARTED."
        break
    }
    Start-Sleep -Seconds 5
}

Write-Host ""
Write-Host "============================================================"
Write-Host "Lab de teste '$LabTitle' criado e iniciado."
Write-Host "lab_id = $LabId"
Write-Host "Confira a convergencia OSPF pelo console/GUI do CML2:"
Write-Host "  show ip ospf neighbor"
Write-Host "  show ip route ospf"
Write-Host "Depois, remova com: cml_lab_powershell_cleanup.ps1"
Write-Host "============================================================"
