[CmdletBinding()]
param(
  [string]$CwgenSource,
  [string]$WorkRoot,
  [string]$GitInstallerPath,
  [string]$GitInstallerUrl,
  [string]$GitInstallerSha256,
  [ValidateSet('all', 'both', 'missing-git-bash', 'auto-install', 'setup-options', 'setup-prompts', 'check-only')]
  [string]$Mode = 'all'
)

$ErrorActionPreference = 'Stop'

function Write-Info {
  param([string]$Message)
  Write-Host "[INFO] $Message"
}

function Resolve-RequiredPath {
  param(
    [string]$Path,
    [string]$Description
  )

  if (-not (Test-Path -LiteralPath $Path)) {
    throw "$Description was not found: $Path"
  }

  (Resolve-Path -LiteralPath $Path).Path
}

function Test-GitBash {
  $Candidates = @(
    "$env:ProgramFiles\Git\bin\bash.exe",
    "$env:ProgramFiles\Git\usr\bin\bash.exe",
    "${env:ProgramFiles(x86)}\Git\bin\bash.exe",
    "$env:LocalAppData\Programs\Git\bin\bash.exe"
  )

  foreach ($Candidate in $Candidates) {
    if ($Candidate -and (Test-Path -LiteralPath $Candidate)) {
      return $true
    }
  }

  return $false
}

function Test-AutoInstallRequested {
  param([string]$SelectedMode)
  $SelectedMode -eq 'all' -or
    $SelectedMode -eq 'both' -or
    $SelectedMode -eq 'auto-install' -or
    $SelectedMode -eq 'setup-options' -or
    $SelectedMode -eq 'setup-prompts'
}

function Resolve-LatestGitInstallerUrl {
  $ReleaseUri = 'https://api.github.com/repos/git-for-windows/git/releases/latest'
  Write-Info "Resolving latest Git for Windows installer URL from $ReleaseUri"

  $Release = Invoke-RestMethod -Uri $ReleaseUri -Headers @{ 'User-Agent' = 'cwgen-integration' }
  $Asset = $Release.assets |
    Where-Object { $_.name -match '^Git-[0-9].*-64-bit\.exe$' -and $_.name -notmatch 'Portable|MinGit' } |
    Select-Object -First 1

  if (-not $Asset) {
    throw 'Could not resolve a 64-bit Git for Windows installer asset from the latest GitHub release.'
  }

  Write-Info "Using Git for Windows installer asset: $($Asset.name)"
  $Asset.browser_download_url
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $ScriptDir '..\..')).Path
$BootstrapScript = Join-Path $RepoRoot 'scripts\windows-sandbox\bootstrap-install-smoke.ps1'

if ([string]::IsNullOrWhiteSpace($CwgenSource)) {
  $CwgenSource = Join-Path (Split-Path -Parent $RepoRoot) 'cwgen'
}

if ([string]::IsNullOrWhiteSpace($WorkRoot)) {
  $WorkRoot = Join-Path $RepoRoot 'target\windows-ci'
}

$CwgenSource = Resolve-RequiredPath -Path $CwgenSource -Description 'CWRGen source directory'
$BootstrapScript = Resolve-RequiredPath -Path $BootstrapScript -Description 'Windows smoke bootstrap script'
$InstallBat = Join-Path $CwgenSource 'install.bat'
if (-not (Test-Path -LiteralPath $InstallBat)) {
  throw "CWRGen source directory does not contain install.bat: $CwgenSource"
}

New-Item -ItemType Directory -Force -Path $WorkRoot | Out-Null
$WorkRoot = (Resolve-Path -LiteralPath $WorkRoot).Path

if (-not [string]::IsNullOrWhiteSpace($GitInstallerPath)) {
  $GitInstallerPath = Resolve-RequiredPath -Path $GitInstallerPath -Description 'Git for Windows installer'
}
elseif (
  (Test-AutoInstallRequested $Mode) -and
  -not (Test-GitBash) -and
  [string]::IsNullOrWhiteSpace($GitInstallerUrl)
) {
  $GitInstallerUrl = Resolve-LatestGitInstallerUrl
}

$BootstrapArgs = @{
  CwgenRoot = $CwgenSource
  WorkRoot = $WorkRoot
  Mode = $Mode
  NoShutdown = $true
}

if (-not [string]::IsNullOrWhiteSpace($GitInstallerPath)) {
  $BootstrapArgs.GitInstallerPath = $GitInstallerPath
}

if (-not [string]::IsNullOrWhiteSpace($GitInstallerUrl)) {
  $BootstrapArgs.GitInstallerUrl = $GitInstallerUrl
}

if (-not [string]::IsNullOrWhiteSpace($GitInstallerSha256)) {
  $BootstrapArgs.GitInstallerSha256 = $GitInstallerSha256
}

Write-Info "Running Windows install smoke tests against $CwgenSource"
& $BootstrapScript @BootstrapArgs

$StatusPath = Join-Path $WorkRoot 'status.txt'
if (-not (Test-Path -LiteralPath $StatusPath)) {
  throw "Windows smoke status file was not written: $StatusPath"
}

$Status = (Get-Content -Raw -LiteralPath $StatusPath).Trim()
Write-Info "Windows smoke status: $Status"
if ($Status -ne 'PASS') {
  throw "Windows smoke tests did not pass: $Status"
}
