# vicoop-provider installer for Windows (PowerShell).
#
#   irm https://raw.githubusercontent.com/planetarium/vicoop-provider/main/install.ps1 | iex
#
# Resolves the latest release (or $env:VERSION), downloads the windows-x64
# standalone binary, verifies its SHA256 checksum, and installs it as
# vicoop-provider.exe (adding the install dir to your user PATH).
#
# Release binaries live in a dedicated PUBLIC repo (the source repo is internal),
# so no token is needed.
#
# Environment overrides:
#   $env:VERSION      Install this exact version instead of the latest (e.g. 0.2.1).
#   $env:INSTALL_DIR  Install into this directory (default:
#                     %LOCALAPPDATA%\Programs\vicoop-provider).

$ErrorActionPreference = 'Stop'
$Repo = 'planetarium/vicoop-provider'

function Fail($msg) { Write-Error "install: $msg"; exit 1 }

if (-not [Environment]::Is64BitOperatingSystem) { Fail 'only 64-bit Windows is supported' }

# --- resolve version ---------------------------------------------------------
$version = $env:VERSION
if (-not $version) {
  try {
    $rel = Invoke-RestMethod -Headers @{ 'User-Agent' = 'vicoop-provider-cli' } `
      "https://api.github.com/repos/$Repo/releases/latest"
    $version = $rel.tag_name
  } catch { Fail 'could not resolve the latest version from the GitHub API' }
}
$version = $version -replace '^v', ''

$name = "vicoop-provider-$version-windows-x64.exe"
$base = "https://github.com/$Repo/releases/download/v$version"

# --- download + verify (in a temp dir) ---------------------------------------
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("vicoop-provider-" + [System.Guid]::NewGuid())
New-Item -ItemType Directory -Path $tmp | Out-Null
try {
  Write-Host "install: downloading $name"
  Invoke-WebRequest -UseBasicParsing -Uri "$base/$name" -OutFile (Join-Path $tmp $name)
  Invoke-WebRequest -UseBasicParsing -Uri "$base/SHA256SUMS.txt" -OutFile (Join-Path $tmp 'SHA256SUMS.txt')

  $expected = Get-Content (Join-Path $tmp 'SHA256SUMS.txt') |
    Where-Object { $_ -match "\s\*?$([regex]::Escape($name))\s*$" } |
    ForEach-Object { ($_ -split '\s+')[0] } |
    Select-Object -First 1
  if (-not $expected) { Fail "no checksum entry for $name in SHA256SUMS.txt" }

  $actual = (Get-FileHash -Algorithm SHA256 (Join-Path $tmp $name)).Hash.ToLower()
  if ($actual -ne $expected.ToLower()) {
    Fail "checksum mismatch for $name (expected $expected, got $actual)"
  }
  Write-Host 'install: checksum verified'

  # --- choose install dir ----------------------------------------------------
  $dir = $env:INSTALL_DIR
  if (-not $dir) { $dir = Join-Path $env:LOCALAPPDATA 'Programs\vicoop-provider' }
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  $dest = Join-Path $dir 'vicoop-provider.exe'
  Move-Item -Force (Join-Path $tmp $name) $dest

  # add to the user PATH if missing
  $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
  if (($userPath -split ';') -notcontains $dir) {
    [Environment]::SetEnvironmentVariable('Path', ($userPath.TrimEnd(';') + ';' + $dir), 'User')
    Write-Host "install: added $dir to your user PATH (restart the shell to pick it up)"
  }

  Write-Host "install: installed vicoop-provider $version -> $dest"
  & $dest --version
} finally {
  Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}
