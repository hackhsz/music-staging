$ErrorActionPreference = 'Stop'
$root = git rev-parse --show-toplevel
if (-not $?) { exit 1 }
git -C $root config core.hooksPath .githooks
if (-not $?) { exit 1 }
Write-Host 'Hooks enabled: core.hooksPath=.githooks'
