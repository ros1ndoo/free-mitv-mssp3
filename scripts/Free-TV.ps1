#requires -Version 7.0
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][ValidateSet('Inspect','Apply','Verify','Restore')][string]$Action,
    [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9._:-]+$')][string]$Device,
    [string]$Adb = 'adb',
    [ValidateRange(1024,65535)][int]$ServerPort = 5037,
    [string]$StateFile = (Join-Path $PSScriptRoot '../state/baseline.json')
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$packages = @(
    'com.google.android.tvlauncher',
    'com.google.android.leanbacklauncher',
    'com.mitv.tvhome.atv',
    'com.mitv.tvhome.michannel',
    'com.miui.tv.analytics',
    'com.xiaomi.statistic',
    'com.google.android.tvrecommendations',
    'com.google.android.leanbacklauncher.recommendations'
)
$animations = @('window_animation_scale','transition_animation_scale','animator_duration_scale')
$projectivy = 'com.spocky.projengmenu/.ui.home.MainActivity'

function Invoke-Adb([string[]]$Arguments) {
    $output = & $Adb -P $ServerPort -s $Device @Arguments 2>&1
    $code = $LASTEXITCODE
    $result = ($output | Out-String).Trim()
    if ($code -ne 0 -or $result -match '(?im)^(error:|Error:|Failure|Security exception|Exception occurred)') {
        throw "ADB falló ($code): $result"
    }
    return $result
}
function Shell([string[]]$Arguments) { Invoke-Adb (@('shell') + $Arguments) }
function Property([string]$Name) { Shell @('getprop',$Name) }
function HomeActivity {
    $result = Shell @('cmd','package','resolve-activity','--brief','-a','android.intent.action.MAIN','-c','android.intent.category.HOME')
    $component = @($result -split '\r?\n' | Where-Object { $_ -match '^[\w.]+/[\w.$]+$' })
    if ($component.Count -ne 1) { throw "No se pudo identificar HOME: $result" }
    $component[0]
}
function PackageState([string]$Name) {
    $dump = Shell @('dumpsys','package',$Name)
    if ($dump -notmatch 'User 0:.*?installed=true.*?enabled=(\d+)') { throw "Paquete ausente o no instalado para usuario 0: $Name" }
    [int]$Matches[1]
}
function Check-Configuration {
    if ((HomeActivity) -ne $projectivy) { throw 'HOME no apunta a Projectivy.' }
    foreach ($name in $packages) {
        if ((PackageState $name) -ne 3) { throw "Paquete no desactivado para usuario 0: $name" }
    }
    foreach ($name in $animations) {
        if ((Shell @('settings','get','global',$name)) -notmatch '^0(?:\.0+)?$') { throw "Animación no desactivada: $name" }
    }
    Write-Output 'PASS: HOME, ocho paquetes y tres escalas de animación.'
}

if ((Invoke-Adb @('get-state')) -ne 'device') { throw 'Conecta y autoriza el dispositivo con adb antes de continuar.' }
$identity = [ordered]@{
    model = Property 'ro.product.model'
    device = Property 'ro.product.device'
    firmware = Property 'ro.build.display.id'
    fingerprint = Property 'ro.build.fingerprint'
    serial = Property 'ro.serialno'
}
if ($identity.model -ne 'MiTV-MSSP3' -or $identity.device -ne 'machuca') { throw 'Modelo no admitido: se requiere MiTV-MSSP3 / machuca.' }
if ($Action -eq 'Inspect') {
    [pscustomobject]$identity
    Write-Output "HOME: $(HomeActivity)"
    Write-Output "Parche: $(Property 'ro.build.version.security_patch')"
    foreach ($name in $packages) { Write-Output "$name : $(PackageState $name)" }
    exit 0
}
if ($identity.firmware -ne 'PI.7524 release-keys') { throw 'Firmware fuera del perfil validado: PI.7524 release-keys.' }
if ($Action -eq 'Verify') { Check-Configuration; exit 0 }

if ($Action -eq 'Restore') {
    $baseline = Get-Content -LiteralPath $StateFile -Raw | ConvertFrom-Json -AsHashtable
    if ($baseline.schema -ne 1 -or $baseline.identity.fingerprint -ne $identity.fingerprint -or
        [string]::IsNullOrWhiteSpace($identity.serial) -or $baseline.identity.serial -ne $identity.serial) {
        throw 'El respaldo no corresponde a este dispositivo y firmware.'
    }
    if ($baseline.home -notmatch '^[\w.]+/[\w.$]+$') { throw 'HOME no válido en el respaldo.' }
    foreach ($name in $packages) {
        if (-not $baseline.packages.ContainsKey($name) -or $baseline.packages[$name] -notin @(0,1,2,3,4)) { throw "Estado inválido: $name" }
    }
    foreach ($name in $animations) {
        if (-not $baseline.animations.ContainsKey($name) -or [string]$baseline.animations[$name] -notmatch '^(null|[0-9]+(?:\.[0-9]+)?)$') { throw "Valor inválido: $name" }
    }
    if ($PSCmdlet.ShouldProcess($Device,'Restaurar el estado exacto guardado')) {
        # Primero se recuperan los launchers para no dejar HOME sin destino.
        $commands = @{0='default-state';1='enable';2='disable';3='disable-user';4='disable-until-used'}
        foreach ($name in $packages) { Shell @('pm',$commands[[int]$baseline.packages[$name]],'--user','0',$name) | Out-Null }
        foreach ($name in $animations) {
            $value = [string]$baseline.animations[$name]
            if ($value -eq 'null') { Shell @('settings','delete','global',$name) | Out-Null }
            else { Shell @('settings','put','global',$name,$value) | Out-Null }
        }
        Shell @('cmd','package','set-home-activity','--user','0',$baseline.home) | Out-Null
        if ((HomeActivity) -ne $baseline.home) { throw 'La restauración de HOME necesita revisión.' }
        foreach ($name in $packages) { if ((PackageState $name) -ne $baseline.packages[$name]) { throw "No se restauró $name" } }
        foreach ($name in $animations) { if ((Shell @('settings','get','global',$name)) -ne [string]$baseline.animations[$name]) { throw "No se restauró $name" } }
        Shell @('input','keyevent','KEYCODE_HOME') | Out-Null
        Write-Output 'Restauración verificada. Se conserva el respaldo.'
    }
    exit 0
}

# Preflight completo antes de cambiar el televisor.
if ([string]::IsNullOrWhiteSpace($identity.serial)) { throw 'No hay identificador estable para asociar el respaldo.' }
if ((PackageState 'com.spocky.projengmenu') -notin @(0,1)) { throw 'Instala y habilita Projectivy antes de aplicar.' }
$baseline = [ordered]@{ schema=1; createdUtc=[DateTime]::UtcNow.ToString('o'); identity=$identity; home=HomeActivity; packages=@{}; animations=@{} }
foreach ($name in $packages) { $baseline.packages[$name] = PackageState $name }
foreach ($name in $animations) { $baseline.animations[$name] = Shell @('settings','get','global',$name) }
if (Test-Path -LiteralPath $StateFile) { throw 'Ya existe un respaldo. Usa Verify o Restore; no se sobrescribe la línea base.' }
if ($PSCmdlet.ShouldProcess($Device,'Guardar respaldo, establecer Projectivy y aplicar el perfil de rendimiento')) {
    $fullStatePath = [IO.Path]::GetFullPath($StateFile)
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($fullStatePath)) | Out-Null
    # CreateNew evita sobrescribir incluso si otro proceso creó el archivo.
    $stream = [IO.File]::Open($fullStatePath,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write)
    try {
        $bytes = [Text.Encoding]::UTF8.GetBytes(($baseline | ConvertTo-Json -Depth 6))
        $stream.Write($bytes,0,$bytes.Length)
    } finally { $stream.Dispose() }
    try {
        $start = Shell @('am','start','-W','-n',$projectivy)
        if ($start -notmatch 'Status: ok') { throw "Projectivy no arrancó: $start" }
        foreach ($name in $packages) { Shell @('pm','disable-user','--user','0',$name) | Out-Null }
        foreach ($name in $animations) { Shell @('settings','put','global',$name,'0') | Out-Null }
        Shell @('cmd','package','set-home-activity','--user','0',$projectivy) | Out-Null
        Check-Configuration
        Shell @('input','keyevent','KEYCODE_HOME') | Out-Null
    } catch {
        Write-Warning "Aplicación incompleta. Conserva $fullStatePath y ejecuta Restore."
        throw
    }
}
