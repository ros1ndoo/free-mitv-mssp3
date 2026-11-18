#requires -Version 7.0
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot
$run = Join-Path $root ('test-results/' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $run -Force | Out-Null
$env:FTV_MOCK_FILE = Join-Path $run 'device.json'
$env:FTV_MOCK_FAIL = ''
$baseline = Join-Path $run 'baseline.json'
$fixture = @{
    props = @{'ro.product.model'='MiTV-MSSP3';'ro.product.device'='machuca';'ro.build.display.id'='PI.7524 release-keys';'ro.build.fingerprint'='fixture-fingerprint';'ro.serialno'='fixture-serial';'ro.build.version.security_patch'='2021-10-05'}
    home='com.google.android.tvlauncher/.MainActivity'
    packages=@{
        'com.spocky.projengmenu'=0;'com.google.android.tvlauncher'=0;'com.google.android.leanbacklauncher'=1
        'com.mitv.tvhome.atv'=0;'com.mitv.tvhome.michannel'=0;'com.miui.tv.analytics'=3
        'com.xiaomi.statistic'=0;'com.google.android.tvrecommendations'=0;'com.google.android.leanbacklauncher.recommendations'=0
    }
    animations=@{window_animation_scale='1.0';transition_animation_scale='0.5';animator_duration_scale='null'}
}
function Reset-Fixture { $fixture | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $env:FTV_MOCK_FILE }
function Run([string]$Action,[bool]$Success=$true,[switch]$DryRun,[string]$Backup=$baseline) {
    $cli = @('-NoProfile','-File',(Join-Path $root 'scripts/Free-TV.ps1'),'-Action',$Action,'-Device','fixture:5555','-Adb',(Join-Path $PSScriptRoot 'Mock-Adb.ps1'),'-StateFile',$Backup)
    if ($DryRun) { $cli += '-WhatIf' }
    $log = & pwsh @cli 2>&1
    if (($LASTEXITCODE -eq 0) -ne $Success) { throw "Resultado inesperado $Action : $log" }
}
function Assert([bool]$Condition,[string]$Message) { if (-not $Condition) { throw $Message } }
Reset-Fixture
Run Inspect
Run Apply -DryRun
Assert (-not (Test-Path -LiteralPath $baseline)) 'WhatIf creó un respaldo.'
$after = Get-Content -Raw $env:FTV_MOCK_FILE | ConvertFrom-Json -AsHashtable
Assert ($after.home -eq $fixture.home -and $after.packages['com.google.android.tvlauncher'] -eq 0) 'WhatIf alteró el inicio.'
Run Apply
Run Verify
$hash = (Get-FileHash -LiteralPath $baseline).Hash
Run Apply -Success $false
Assert ((Get-FileHash -LiteralPath $baseline).Hash -eq $hash) 'Se sobrescribió la línea base.'
Run Restore
$after = Get-Content -Raw $env:FTV_MOCK_FILE | ConvertFrom-Json -AsHashtable
Assert ($after.home -eq $fixture.home) 'HOME no restaurado.'
foreach ($key in $fixture.packages.Keys) { Assert ($after.packages[$key] -eq $fixture.packages[$key]) "Estado original perdido: $key" }
foreach ($key in $fixture.animations.Keys) { Assert ($after.animations[$key] -eq $fixture.animations[$key]) "Animación original perdida: $key" }
Write-Output 'PASS: inspección, WhatIf, Apply, Verify, respaldo inmutable y Restore exacto.'

$after.props['ro.product.device'] = 'other-device'
$after | ConvertTo-Json -Depth 6 | Set-Content $env:FTV_MOCK_FILE
Run Apply -Success $false -Backup (Join-Path $run 'wrong.json')
Assert (-not (Test-Path (Join-Path $run 'wrong.json'))) 'Se aceptó un modelo ajeno.'
Reset-Fixture
$after = Get-Content -Raw $env:FTV_MOCK_FILE | ConvertFrom-Json -AsHashtable
$after.props['ro.serialno'] = 'another-unit'
$after | ConvertTo-Json -Depth 6 | Set-Content $env:FTV_MOCK_FILE
Run Restore -Success $false
Reset-Fixture
$partial = Join-Path $run 'partial.json'
$env:FTV_MOCK_FAIL = 'com.mitv.tvhome.atv'
Run Apply -Success $false -Backup $partial
Assert (Test-Path -LiteralPath $partial) 'Fallo parcial sin respaldo.'
$env:FTV_MOCK_FAIL = ''
Run Restore -Backup $partial
Write-Output 'PASS: rechazo de modelo/serie ajenos y restauración tras fallo parcial.'
