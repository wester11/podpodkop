$ErrorActionPreference = "Stop"

if (-not (Test-Path "docs")) {
    New-Item -ItemType Directory -Path "docs" | Out-Null
}

$serviceStats = Get-ChildItem services -Directory | ForEach-Object {
    $domainsPath = Join-Path $_.FullName "domains.srs"
    $subnetsPath = Join-Path $_.FullName "subnets.srs"
    [PSCustomObject]@{
        service = $_.Name
        domains = if (Test-Path $domainsPath) { (Get-Content $domainsPath | Where-Object { $_ -and $_.Trim() }).Count } else { 0 }
        subnets = if (Test-Path $subnetsPath) { (Get-Content $subnetsPath | Where-Object { $_ -and $_.Trim() }).Count } else { 0 }
    }
} | Sort-Object service

$listStats = Get-ChildItem lists -Directory | ForEach-Object {
    $domainsPath = Join-Path $_.FullName "domains.srs"
    $subnetsPath = Join-Path $_.FullName "subnets.srs"
    $servicesPath = Join-Path $_.FullName "services.txt"
    [PSCustomObject]@{
        list = $_.Name
        services = if (Test-Path $servicesPath) { (Get-Content $servicesPath | Where-Object { $_ -and $_.Trim() }).Count } else { 0 }
        domains = if (Test-Path $domainsPath) { (Get-Content $domainsPath | Where-Object { $_ -and $_.Trim() }).Count } else { 0 }
        subnets = if (Test-Path $subnetsPath) { (Get-Content $subnetsPath | Where-Object { $_ -and $_.Trim() }).Count } else { 0 }
    }
} | Sort-Object list

$serviceCount = $serviceStats.Count
$listCount = $listStats.Count
$totalDomains = ($serviceStats | Measure-Object -Property domains -Sum).Sum
$totalSubnets = ($serviceStats | Measure-Object -Property subnets -Sum).Sum

$topDomainServices = $serviceStats | Sort-Object domains -Descending | Select-Object -First 10
$topSubnetServices = $serviceStats | Sort-Object subnets -Descending | Select-Object -First 10

$lines = @()
$lines += "# Database Report"
$lines += ""
$lines += "Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")"
$lines += ""
$lines += "## Summary"
$lines += ""
$lines += "- Services: $serviceCount"
$lines += "- Aggregated lists: $listCount"
$lines += "- Total domain entries across services: $totalDomains"
$lines += "- Total subnet entries across services: $totalSubnets"
$lines += ""
$lines += "## Top services by domains"
$lines += ""
$lines += "| Service | Domains | Subnets |"
$lines += "|---|---:|---:|"
foreach ($x in $topDomainServices) {
    $lines += "| $($x.service) | $($x.domains) | $($x.subnets) |"
}
$lines += ""
$lines += "## Top services by subnets"
$lines += ""
$lines += "| Service | Domains | Subnets |"
$lines += "|---|---:|---:|"
foreach ($x in $topSubnetServices) {
    $lines += "| $($x.service) | $($x.domains) | $($x.subnets) |"
}
$lines += ""
$lines += "## Aggregated list stats"
$lines += ""
$lines += "| List | Services | Domains | Subnets |"
$lines += "|---|---:|---:|---:|"
foreach ($x in $listStats) {
    $lines += "| $($x.list) | $($x.services) | $($x.domains) | $($x.subnets) |"
}

Set-Content -Path "docs/database-report.md" -Value $lines -Encoding utf8
