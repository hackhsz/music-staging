<#
  Download-RobloxImages.ps1
  -------------------------------------------------------------------------
  Downloads Roblox image assets by id and saves each as a PNG.

  Input: a text file of "Name <id>" lines (one per line), e.g.
      Rusty Stove 1234567890
      Golden Stove 1234567891
      Diamond Stove 1234567892
  (Name may contain spaces; the trailing number is the asset id. Blank lines
   and lines without a number are skipped, so you can keep notes/headers.)

  Each is saved to -OutDir as "<Name>.png" (spaces -> underscores).

  Usage (from the project root):
      powershell -ExecutionPolicy Bypass -File tools\scripts\Download-RobloxImages.ps1 `
          -ListFile tools\scripts\image-ids.txt -OutDir DownloadedImages

  Defaults: -ListFile tools\scripts\image-ids.txt  -OutDir DownloadedImages  -Size 420x420
#>
param(
    [string]$ListFile = "tools\scripts\image-ids.txt",
    [string]$OutDir   = "DownloadedImages",
    [string]$Size     = "420x420"
)

if (-not (Test-Path $ListFile)) { Write-Error "List file not found: $ListFile"; exit 1 }
if (-not (Test-Path $OutDir))   { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }

$ok = 0; $fail = 0
foreach ($line in Get-Content $ListFile) {
    $t = $line.Trim()
    if ($t -eq "") { continue }
    # "Some Name 123456" -> name = "Some Name", id = 123456
    $m = [regex]::Match($t, '^(.*?)\s+(\d+)\s*$')
    if (-not $m.Success) { continue }  # header/note line, skip
    $name = $m.Groups[1].Value.Trim()
    $id   = $m.Groups[2].Value
    $safe = ($name -replace '[\\/:*?"<>|]', '_') -replace '\s+', '_'
    $dest = Join-Path $OutDir "$safe.png"

    $url = $null
    # 1) Thumbnail API → rendered PNG url. Roblox generates it on first request, so
    #    poll while state=Pending (up to ~10 tries).
    for ($try = 1; $try -le 10; $try++) {
        try {
            $api = "https://thumbnails.roblox.com/v1/assets?assetIds=$id&size=$Size&format=Png"
            $entry = (Invoke-RestMethod -Uri $api -TimeoutSec 20).data | Select-Object -First 1
            if ($entry.state -eq "Completed" -and -not [string]::IsNullOrEmpty($entry.imageUrl)) {
                $url = $entry.imageUrl; break
            }
        } catch {}
        Start-Sleep -Seconds 2
    }

    try {
        if ($url) {
            Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing -TimeoutSec 30
        } else {
            # 2) Fallback: raw asset delivery (works for plain Image uploads).
            Invoke-WebRequest -Uri "https://assetdelivery.roblox.com/v1/asset/?id=$id" -OutFile $dest -UseBasicParsing -TimeoutSec 30
        }
        $sz = (Get-Item $dest).Length
        Write-Host ("OK   {0,-22} id={1,-12} {2} bytes -> {3}" -f $name, $id, $sz, $dest)
        $ok++
    } catch {
        Write-Host ("FAIL {0,-22} id={1,-12} {2}" -f $name, $id, $_.Exception.Message) -ForegroundColor Red
        $fail++
    }
}
Write-Host ""
Write-Host "Done: $ok downloaded, $fail failed. Folder: $OutDir"
