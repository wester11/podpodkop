$ErrorActionPreference = "Stop"

$servicesRoot = "services"
$listsRoot = "lists"

function Ensure-GroupFiles {
    param(
        [string]$ListName,
        [string[]]$Services
    )

    $listDir = Join-Path $listsRoot $ListName
    if (-not (Test-Path $listDir)) {
        New-Item -ItemType Directory -Path $listDir | Out-Null
    }

    $domains = @()
    $subnets = @()

    foreach ($svc in $Services) {
        $svcDir = Join-Path $servicesRoot $svc
        $domainsPath = Join-Path $svcDir "domains.srs"
        $subnetsPath = Join-Path $svcDir "subnets.srs"
        if (Test-Path $domainsPath) { $domains += Get-Content $domainsPath }
        if (Test-Path $subnetsPath) { $subnets += Get-Content $subnetsPath }
    }

    $domains = $domains | Where-Object { $_ -and $_.Trim().Length -gt 0 } | Sort-Object -Unique
    $subnets = $subnets | Where-Object { $_ -and $_.Trim().Length -gt 0 } | Sort-Object -Unique

    Set-Content -Path (Join-Path $listDir "domains.srs") -Value $domains -Encoding ascii
    Set-Content -Path (Join-Path $listDir "subnets.srs") -Value $subnets -Encoding ascii
    Set-Content -Path (Join-Path $listDir "services.txt") -Value ($Services | Sort-Object -Unique) -Encoding ascii
}

if (-not (Test-Path $listsRoot)) {
    New-Item -ItemType Directory -Path $listsRoot | Out-Null
}

$lists = [ordered]@{
    "ai_all" = @("chatgpt","claude","cursor","gemini","perplexity","midjourney","microsoft_copilot","deepseek","grok","poe","huggingface")
    "social_networks" = @("facebook","instagram","x_twitter","linkedin","tiktok","snapchat","pinterest")
    "messengers_calls" = @("telegram","whatsapp","signal","viber","discord","protonmail","facetime")
    "social_messaging" = @("telegram","whatsapp","facebook","instagram","x_twitter","linkedin","tiktok","snapchat","discord","signal","viber")
    "video_audio_streaming" = @("youtube","twitch","spotify","dailymotion","soundcloud")
    "news_media" = @("bbc","cnn","associated_press","wsj","radio_svoboda","euronews","meduza","dw","google_news")
    "creator_platforms" = @("patreon","envato","canva","metacritic","soundcloud","behance","deviantart")
    "gaming" = @("roblox","metacritic")
    "developer_platforms" = @("github","gitlab","huggingface","stackoverflow")
    "productivity_tools" = @("notion","figma","canva","trello","miro")
    "cloud_storage" = @("dropbox","onedrive","mega")
    "forums_communities" = @("reddit","quora","medium","stackoverflow")
}

$allServices = Get-ChildItem -Path $servicesRoot -Directory | Select-Object -ExpandProperty Name | Sort-Object
$lists["all_services"] = $allServices

foreach ($listName in $lists.Keys) {
    Ensure-GroupFiles -ListName $listName -Services $lists[$listName]
}
