$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$pubspecPath = Join-Path $root 'pubspec.yaml'
$localPropertiesPath = Join-Path $root 'android\local.properties'

if (-not (Test-Path $pubspecPath)) {
  throw "Arquivo nao encontrado: $pubspecPath"
}
if (-not (Test-Path $localPropertiesPath)) {
  throw "Arquivo nao encontrado: $localPropertiesPath"
}

# Lê e atualiza pubspec.yaml
$pubspec = Get-Content -Path $pubspecPath -Encoding UTF8 -Raw

$m = [regex]::Match($pubspec, '(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+(\d+)')
if (-not $m.Success) {
  throw 'Nao foi possivel encontrar versao no formato x.y.z+N no pubspec.yaml'
}

$oldBaseVersion = $m.Groups[1].Value
$oldCode        = [int]$m.Groups[2].Value
$newCode        = $oldCode + 1
$newVersion     = "$oldBaseVersion+$newCode"

$pubspec = $pubspec -replace '(?m)^version:\s*[0-9]+\.[0-9]+\.[0-9]+\+\d+', "version: $newVersion"

$encoding = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($pubspecPath, $pubspec, $encoding)

# Lê e atualiza android/local.properties
$props = Get-Content -Path $localPropertiesPath -Encoding UTF8 -Raw

if ($props -notmatch '(?m)^flutter\.versionCode=\d+') {
  throw 'Nao foi possivel encontrar flutter.versionCode no android/local.properties'
}
if ($props -notmatch '(?m)^flutter\.versionName=') {
  throw 'Nao foi possivel encontrar flutter.versionName no android/local.properties'
}

$props = $props -replace '(?m)^flutter\.versionCode=\d+', "flutter.versionCode=$newCode"
$props = $props -replace '(?m)^flutter\.versionName=[^\r\n]*', "flutter.versionName=$oldBaseVersion"

[System.IO.File]::WriteAllText($localPropertiesPath, $props, $encoding)

Write-Host "Versao Android atualizada: $oldBaseVersion+$oldCode -> $newVersion"