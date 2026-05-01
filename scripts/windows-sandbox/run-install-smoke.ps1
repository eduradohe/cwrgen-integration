[CmdletBinding()]
param(
  [string]$CwgenSource,
  [string]$GitInstallerPath,
  [string]$GitInstallerUrl,
  [string]$GitInstallerSha256,
  [ValidateSet('all', 'both', 'missing-git-bash', 'auto-install', 'setup-options', 'setup-prompts', 'check-only')]
  [string]$Mode = 'all',
  [switch]$KeepOpen,
  [switch]$GenerateOnly
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

function ConvertTo-WsbText {
  param([string]$Value)
  [System.Security.SecurityElement]::Escape($Value)
}

function ConvertTo-PowerShellArgument {
  param([string]$Value)
  '"{0}"' -f (($Value -replace '`', '``') -replace '"', '`"')
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

  $Release = Invoke-RestMethod -Uri $ReleaseUri -Headers @{ 'User-Agent' = 'cwrgen-integration' }
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

if ([string]::IsNullOrWhiteSpace($CwgenSource)) {
  $CwgenSource = Join-Path (Split-Path -Parent $RepoRoot) 'cwgen'
}

$CwgenSource = Resolve-RequiredPath -Path $CwgenSource -Description 'CWRGen source directory'
$InstallBat = Join-Path $CwgenSource 'install.bat'
if (-not (Test-Path -LiteralPath $InstallBat)) {
  throw "CWRGen source directory does not contain install.bat: $CwgenSource"
}

$SandboxExe = Join-Path $env:SystemRoot 'System32\WindowsSandbox.exe'
if (-not (Test-Path -LiteralPath $SandboxExe)) {
  throw 'Windows Sandbox is not installed or WindowsSandbox.exe is not on this machine.'
}

$TargetRoot = Join-Path $RepoRoot 'target\windows-sandbox'
$LogRoot = Join-Path $TargetRoot 'logs'
$CacheRoot = Join-Path $TargetRoot 'cache'
$WsbPath = Join-Path $TargetRoot 'cwrgen-install-smoke.wsb'
$StatusPath = Join-Path $TargetRoot 'status.txt'
$HarnessDir = (Resolve-Path -LiteralPath $ScriptDir).Path

New-Item -ItemType Directory -Force -Path $TargetRoot, $LogRoot, $CacheRoot | Out-Null
Remove-Item -LiteralPath $StatusPath -Force -ErrorAction SilentlyContinue

$BootstrapCommand = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Sandbox\harness\bootstrap-install-smoke.ps1 -Mode {0}' -f $Mode

if (Test-AutoInstallRequested $Mode) {
  if (-not [string]::IsNullOrWhiteSpace($GitInstallerPath)) {
    $GitInstallerPath = Resolve-RequiredPath -Path $GitInstallerPath -Description 'Git for Windows installer'
    $CachedInstallerPath = Join-Path $CacheRoot (Split-Path -Leaf $GitInstallerPath)
    Copy-Item -LiteralPath $GitInstallerPath -Destination $CachedInstallerPath -Force
    $SandboxInstallerPath = 'C:\Sandbox\work\cache\' + (Split-Path -Leaf $CachedInstallerPath)
    $BootstrapCommand = "$BootstrapCommand -GitInstallerPath $(ConvertTo-PowerShellArgument $SandboxInstallerPath)"
  }
  elseif (-not [string]::IsNullOrWhiteSpace($GitInstallerUrl)) {
    $BootstrapCommand = "$BootstrapCommand -GitInstallerUrl $(ConvertTo-PowerShellArgument $GitInstallerUrl)"
  }
  else {
    $GitInstallerUrl = Resolve-LatestGitInstallerUrl
    $BootstrapCommand = "$BootstrapCommand -GitInstallerUrl $(ConvertTo-PowerShellArgument $GitInstallerUrl)"
  }

  if (-not [string]::IsNullOrWhiteSpace($GitInstallerSha256)) {
    $BootstrapCommand = "$BootstrapCommand -GitInstallerSha256 $(ConvertTo-PowerShellArgument $GitInstallerSha256)"
  }
}

if ($KeepOpen) {
  $BootstrapCommand = "$BootstrapCommand -KeepOpen"
}

$WsbContent = @"
<Configuration>
  <Networking>Enable</Networking>
  <ClipboardRedirection>Disable</ClipboardRedirection>
  <PrinterRedirection>Disable</PrinterRedirection>
  <MappedFolders>
    <MappedFolder>
      <HostFolder>$(ConvertTo-WsbText $CwgenSource)</HostFolder>
      <SandboxFolder>C:\Sandbox\cwgen</SandboxFolder>
      <ReadOnly>true</ReadOnly>
    </MappedFolder>
    <MappedFolder>
      <HostFolder>$(ConvertTo-WsbText $HarnessDir)</HostFolder>
      <SandboxFolder>C:\Sandbox\harness</SandboxFolder>
      <ReadOnly>true</ReadOnly>
    </MappedFolder>
    <MappedFolder>
      <HostFolder>$(ConvertTo-WsbText $TargetRoot)</HostFolder>
      <SandboxFolder>C:\Sandbox\work</SandboxFolder>
      <ReadOnly>false</ReadOnly>
    </MappedFolder>
  </MappedFolders>
  <LogonCommand>
    <Command>$(ConvertTo-WsbText $BootstrapCommand)</Command>
  </LogonCommand>
</Configuration>
"@

Set-Content -LiteralPath $WsbPath -Value $WsbContent -Encoding UTF8

Write-Info "Windows Sandbox config written to $WsbPath"
Write-Info "Sandbox logs will be written to $LogRoot"
Write-Info "Sandbox status will be written to $StatusPath"

if ($GenerateOnly) {
  Write-Info 'GenerateOnly was used; Windows Sandbox was not started.'
  exit 0
}

Write-Info 'Starting Windows Sandbox. The test continues inside the Sandbox window.'
Start-Process -FilePath $SandboxExe -ArgumentList "`"$WsbPath`""
