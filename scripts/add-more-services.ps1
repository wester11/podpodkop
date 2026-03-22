$ErrorActionPreference = "Stop"

function Ensure-File {
    param(
        [string]$Path,
        [string[]]$Lines
    )

    $dir = Split-Path -Parent $Path
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
    $clean = $Lines | Where-Object { $_ -and $_.Trim().Length -gt 0 } | Sort-Object -Unique
    Set-Content -Path $Path -Value $clean -Encoding ascii
}

$cloudflare = @(
    "103.21.244.0/22","103.22.200.0/22","103.31.4.0/22","104.16.0.0/13","104.24.0.0/14",
    "108.162.192.0/18","131.0.72.0/22","141.101.64.0/18","162.158.0.0/15","172.64.0.0/13",
    "173.245.48.0/20","188.114.96.0/20","190.93.240.0/20","197.234.240.0/22","198.41.128.0/17",
    "2400:cb00::/32","2606:4700::/32","2a06:98c0::/29"
)

$fastly = @("151.101.0.0/16","199.232.0.0/16","2a04:4e42::/32")
$google = @("64.233.160.0/19","66.102.0.0/20","66.249.80.0/20","72.14.192.0/18","74.125.0.0/16","108.177.8.0/21","142.250.0.0/15","172.217.0.0/16","173.194.0.0/16","216.58.192.0/19","216.239.32.0/19","2001:4860::/32")
$microsoft = @("13.107.0.0/16","20.0.0.0/11","40.64.0.0/10","52.96.0.0/12","104.40.0.0/13","131.253.0.0/16","150.171.0.0/16")
$githubNets = @("140.82.112.0/20","185.199.108.0/22","192.30.252.0/22","20.201.28.151/32","20.205.243.166/32")
$aws = @("3.0.0.0/8","13.32.0.0/15","18.64.0.0/14","52.84.0.0/15","52.222.128.0/17")

$services = @{
    "notion" = @{
        domains = @("notion.so","www.notion.so","notion.site","msgstore.www.notion.so")
        subnets = $cloudflare
    }
    "figma" = @{
        domains = @("figma.com","www.figma.com","api.figma.com")
        subnets = $cloudflare + $fastly
    }
    "github" = @{
        domains = @("github.com","githubassets.com","githubusercontent.com","api.github.com","raw.githubusercontent.com")
        subnets = $githubNets
    }
    "gitlab" = @{
        domains = @("gitlab.com","about.gitlab.com","registry.gitlab.com")
        subnets = $cloudflare + @("35.231.145.151/32")
    }
    "reddit" = @{
        domains = @("reddit.com","www.reddit.com","redd.it","redditstatic.com","redditmedia.com")
        subnets = $fastly + $aws
    }
    "quora" = @{
        domains = @("quora.com","www.quora.com","qph.cf2.quoracdn.net")
        subnets = $cloudflare
    }
    "pinterest" = @{
        domains = @("pinterest.com","pinimg.com","pinterestcdn.com")
        subnets = $cloudflare + $fastly
    }
    "medium" = @{
        domains = @("medium.com","cdn-static-1.medium.com","miro.medium.com")
        subnets = $fastly
    }
    "deviantart" = @{
        domains = @("deviantart.com","www.deviantart.com","st.deviantart.net")
        subnets = $cloudflare
    }
    "behance" = @{
        domains = @("behance.net","www.behance.net","a5.behance.net")
        subnets = $cloudflare
    }
    "dropbox" = @{
        domains = @("dropbox.com","www.dropbox.com","dropboxusercontent.com","dl.dropboxusercontent.com")
        subnets = @("162.125.0.0/16","199.47.216.0/22","45.58.64.0/20","2620:100:6000::/40")
    }
    "onedrive" = @{
        domains = @("onedrive.live.com","live.com","sharepoint.com","1drv.com")
        subnets = $microsoft
    }
    "mega" = @{
        domains = @("mega.nz","mega.io","userstorage.mega.co.nz")
        subnets = $cloudflare
    }
    "deepseek" = @{
        domains = @("deepseek.com","chat.deepseek.com","api.deepseek.com")
        subnets = $cloudflare
    }
    "grok" = @{
        domains = @("grok.com","x.ai","api.x.ai")
        subnets = $cloudflare
    }
    "poe" = @{
        domains = @("poe.com","www.poe.com")
        subnets = $cloudflare
    }
    "huggingface" = @{
        domains = @("huggingface.co","hf.space","cdn-lfs.huggingface.co")
        subnets = $cloudflare + $fastly
    }
    "stackoverflow" = @{
        domains = @("stackoverflow.com","stackexchange.com","sstatic.net")
        subnets = $cloudflare + $fastly
    }
    "trello" = @{
        domains = @("trello.com","api.trello.com","atlassian.com")
        subnets = $cloudflare + $fastly
    }
    "miro" = @{
        domains = @("miro.com","realtimeboard.com")
        subnets = $cloudflare
    }
}

foreach ($name in $services.Keys) {
    Ensure-File "services/$name/domains.srs" $services[$name].domains
    Ensure-File "services/$name/subnets.srs" $services[$name].subnets
}
