$ErrorActionPreference = "Stop"

$services = Get-ChildItem services -Directory | Select-Object -ExpandProperty Name | Sort-Object
$lists = Get-ChildItem lists -Directory | Select-Object -ExpandProperty Name | Sort-Object

$obj = [ordered]@{
    generated_at = (Get-Date).ToString("s")
    services = $services
    lists = $lists
}

if (-not (Test-Path "selector")) {
    New-Item -ItemType Directory -Path "selector" | Out-Null
}

$json = $obj | ConvertTo-Json -Depth 4
Set-Content -Path "selector/catalog.json" -Value $json -Encoding utf8
