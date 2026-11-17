$gitExe = (Get-Command git -ErrorAction Stop).Source
$sh = Join-Path (Split-Path (Split-Path $gitExe)) 'bin\sh.exe'
if (-not (Test-Path $sh)) { $sh = 'sh' }
& $sh (Join-Path $PSScriptRoot 'check-clean.sh') @args
exit $LASTEXITCODE
