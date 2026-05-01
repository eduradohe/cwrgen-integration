[CmdletBinding()]
param(
  [string]$CwgenRoot = 'C:\Sandbox\cwgen',
  [string]$WorkRoot = 'C:\Sandbox\work',
  [ValidateSet('all', 'both', 'missing-git-bash', 'auto-install', 'setup-options', 'setup-prompts', 'check-only')]
  [string]$Mode = 'all',
  [string]$GitInstallerPath,
  [string]$GitInstallerUrl,
  [string]$GitInstallerSha256,
  [switch]$KeepOpen,
  [switch]$NoShutdown
)

$ErrorActionPreference = 'Stop'

$UserProfileRoot = $env:USERPROFILE
$LogDir = Join-Path $WorkRoot 'logs'
$TranscriptPath = Join-Path $LogDir 'install-bat-smoke.log'
$StatusPath = Join-Path $WorkRoot 'status.txt'
$InstallPrefix = Join-Path $UserProfileRoot '.cwgen-smoke'
$SetupInstallPrefix = Join-Path $UserProfileRoot '.cwgen-setup-smoke'
$PromptInstallPrefix = Join-Path $UserProfileRoot '.cwgen-prompt-smoke'
$PromptBootstrapPrefix = Join-Path $UserProfileRoot '.cwgen-prompt-bootstrap'
$CheckOnlyPrefix = Join-Path $UserProfileRoot '.cwgen-check-only-smoke'
$KeyRoot = Join-Path $WorkRoot 'keys'
$FixturePrivateKey = Join-Path $KeyRoot 'id_ed25519'
$FixturePublicKey = Join-Path $KeyRoot 'id_ed25519.pub'
$script:LastInstallExitCode = 0
$script:LastInstallOutput = @()

function Write-Log {
  param([string]$Message)
  Write-Host "[CWRGEN-SANDBOX] $Message"
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

function Invoke-InstallBat {
  param([string[]]$Arguments)

  $InstallBat = Join-Path $CwgenRoot 'install.bat'
  $Output = & $InstallBat @Arguments 2>&1
  $script:LastInstallExitCode = $LASTEXITCODE
  $script:LastInstallOutput = @($Output | ForEach-Object { "$_" })
  $Output | ForEach-Object { Write-Host $_ }
}

function Invoke-InstallBatWithInput {
  param(
    [string[]]$Arguments,
    [string[]]$InputLines
  )

  $InstallBat = Join-Path $CwgenRoot 'install.bat'
  $InputPath = Join-Path $WorkRoot 'install-bat-input.txt'
  $InputText = ($InputLines -join "`r`n") + "`r`n"
  Set-Content -LiteralPath $InputPath -Value $InputText -Encoding ASCII

  $ArgumentText = ($Arguments | ForEach-Object {
    if ($_ -match '[\s&()<>^|"]') {
      '"' + ($_ -replace '"', '""') + '"'
    }
    else {
      $_
    }
  }) -join ' '

  $Command = '"' + $InstallBat + '" ' + $ArgumentText + ' < "' + $InputPath + '"'
  $Output = & cmd.exe /d /s /c $Command 2>&1
  $script:LastInstallExitCode = $LASTEXITCODE
  $script:LastInstallOutput = @($Output | ForEach-Object { "$_" })
  $Output | ForEach-Object { Write-Host $_ }
}

function Get-InstallFailureSummary {
  $FailureLine = $script:LastInstallOutput |
    Where-Object { $_ -match '^\[ERROR\]|winget was not found|Git Bash was not found' } |
    Select-Object -Last 1

  if (-not [string]::IsNullOrWhiteSpace($FailureLine)) {
    return $FailureLine
  }

  return "install.bat exit code $($script:LastInstallExitCode)"
}

function Get-GitInstallerSource {
  if (-not [string]::IsNullOrWhiteSpace($GitInstallerPath)) {
    return $GitInstallerPath
  }

  if (-not [string]::IsNullOrWhiteSpace($GitInstallerUrl)) {
    return $GitInstallerUrl
  }

  return ''
}

function Assert-SourceTree {
  $RequiredFiles = @(
    'install.bat',
    'bin\cwrgen',
    'bin\cwrgen.cmd',
    'bin\cw.sh',
    'bin\cwFinish.sh',
    'config\cwgen.properties',
    'config\repos.properties'
  )

  foreach ($RelativePath in $RequiredFiles) {
    $Path = Join-Path $CwgenRoot $RelativePath
    if (-not (Test-Path -LiteralPath $Path)) {
      throw "Required source file was not found in Sandbox: $Path"
    }
  }
}

function Initialize-FixtureKeys {
  New-Item -ItemType Directory -Force -Path $KeyRoot | Out-Null
  Set-Content -LiteralPath $FixturePrivateKey -Value 'fixture private key for installer copy tests' -Encoding ASCII
  Set-Content -LiteralPath $FixturePublicKey -Value 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFixtureOnly cwrgen@example.test' -Encoding ASCII
}

function Add-GitInstallerArguments {
  param([string[]]$Arguments)

  if (-not [string]::IsNullOrWhiteSpace($GitInstallerPath)) {
    $Arguments += @('--git-bash-installer', $GitInstallerPath)
  }

  if (-not [string]::IsNullOrWhiteSpace($GitInstallerUrl)) {
    $Arguments += @('--git-bash-installer-url', $GitInstallerUrl)
  }

  if (-not [string]::IsNullOrWhiteSpace($GitInstallerSha256)) {
    $Arguments += @('--git-bash-installer-sha256', $GitInstallerSha256)
  }

  return $Arguments
}

function Invoke-MissingGitBashTest {
  Write-Log 'Running missing-Git-Bash failure-path test.'

  if (Test-GitBash) {
    Write-Log 'Git Bash is already present; skipping missing-Git-Bash failure-path test.'
    return
  }

  Invoke-InstallBat @(
    '--prefix', $InstallPrefix,
    '--clean',
    '--force-config',
    '--no-update-path'
  )

  if ($script:LastInstallExitCode -eq 0 -and -not ($script:LastInstallOutput -match 'Git Bash was not found')) {
    throw 'install.bat succeeded without Git Bash and without --install-git-bash; expected a failure.'
  }

  Write-Log 'Missing-Git-Bash failure-path test passed.'
}

function Invoke-AutoInstallTest {
  Write-Log 'Running Git-Bash auto-install test.'

  $InstallArgs = @(
    '--prefix', $InstallPrefix,
    '--clean',
    '--force-config',
    '--install-git-bash'
  )

  $InstallArgs = Add-GitInstallerArguments $InstallArgs

  Invoke-InstallBat $InstallArgs

  if ($script:LastInstallExitCode -ne 0) {
    throw "install.bat --install-git-bash failed: $(Get-InstallFailureSummary)"
  }

  $CwrgenCmd = Join-Path $InstallPrefix 'bin\cwrgen.cmd'
  if (-not (Test-Path -LiteralPath $CwrgenCmd)) {
    throw "install.bat --install-git-bash did not install CWRGen: $(Get-InstallFailureSummary)"
  }

  & $CwrgenCmd --help
  if ($LASTEXITCODE -ne 0) {
    throw "Installed cwrgen.cmd --help failed with exit code $LASTEXITCODE."
  }

  $InstallBin = Join-Path $InstallPrefix 'bin'
  $UserPath = [Environment]::GetEnvironmentVariable('Path', 'User')
  $UserPathItems = @()
  if (-not [string]::IsNullOrWhiteSpace($UserPath)) {
    $UserPathItems = $UserPath -split ';'
  }

  if ($UserPathItems -notcontains $InstallBin) {
    throw "User PATH does not contain installed bin directory: $InstallBin"
  }

  Write-Log 'Git-Bash auto-install test passed.'
}

function Invoke-SetupOptionsTest {
  Write-Log 'Running non-interactive setup-environment test.'
  Initialize-FixtureKeys

  $InstallArgs = @(
    '--prefix', $SetupInstallPrefix,
    '--clean',
    '--force-config',
    '--setup-environment',
    '--non-interactive',
    '--setup-package-manager', 'installer',
    '--setup-git-user-name', 'Smooth Setup Tester',
    '--setup-git-user-email', 'smooth@example.test',
    '--setup-ssh-private-key', $FixturePrivateKey,
    '--setup-ssh-public-key', $FixturePublicKey,
    '--no-update-path'
  )

  $InstallArgs = Add-GitInstallerArguments $InstallArgs
  Invoke-InstallBat $InstallArgs

  if ($script:LastInstallExitCode -ne 0) {
    throw "install.bat --setup-environment --non-interactive failed: $(Get-InstallFailureSummary)"
  }

  $CwrgenCmd = Join-Path $SetupInstallPrefix 'bin\cwrgen.cmd'
  if (-not (Test-Path -LiteralPath $CwrgenCmd)) {
    throw "Non-interactive setup did not install CWRGen: $CwrgenCmd"
  }

  $PrivateKeyTarget = Join-Path (Join-Path $UserProfileRoot '.ssh') 'id_ed25519'
  if (-not (Test-Path -LiteralPath $PrivateKeyTarget)) {
    throw "Non-interactive setup did not copy SSH private key: $PrivateKeyTarget"
  }

  $GitEmail = & 'C:\Program Files\Git\cmd\git.exe' config --global user.email
  if ($GitEmail -ne 'smooth@example.test') {
    throw "Non-interactive setup did not configure expected Git email. Actual: $GitEmail"
  }

  & $CwrgenCmd --help
  if ($LASTEXITCODE -ne 0) {
    throw "Non-interactive setup cwrgen.cmd --help failed with exit code $LASTEXITCODE."
  }

  Write-Log 'Non-interactive setup-environment test passed.'
}

function Invoke-CheckOnlyTest {
  Write-Log 'Running check-only test.'

  if (Test-Path -LiteralPath $CheckOnlyPrefix) {
    Remove-Item -Recurse -Force -LiteralPath $CheckOnlyPrefix
  }

  Invoke-InstallBat @(
    '--prefix', $CheckOnlyPrefix,
    '--check-only'
  )

  if ($script:LastInstallExitCode -ne 0) {
    throw "install.bat --check-only failed: $(Get-InstallFailureSummary)"
  }

  if (Test-Path -LiteralPath $CheckOnlyPrefix) {
    throw "install.bat --check-only created the install prefix: $CheckOnlyPrefix"
  }

  Write-Log 'Check-only test passed.'
}

function Invoke-SetupPromptsTest {
  Write-Log 'Running prompted setup-environment test.'
  Initialize-FixtureKeys

  if (-not (Test-GitBash)) {
    $BootstrapArgs = @(
      '--prefix', $PromptBootstrapPrefix,
      '--clean',
      '--force-config',
      '--install-git-bash',
      '--no-update-path'
    )
    $BootstrapArgs = Add-GitInstallerArguments $BootstrapArgs
    Invoke-InstallBat $BootstrapArgs

    if ($script:LastInstallExitCode -ne 0) {
      throw "Prompted setup could not bootstrap Git Bash: $(Get-InstallFailureSummary)"
    }
  }

  $InstallArgs = @(
    '--prefix', $PromptInstallPrefix,
    '--clean',
    '--force-config',
    '--setup-environment',
    '--no-update-path'
  )

  $InputLines = @(
    'Prompt Setup Tester',
    'prompt@example.test',
    $FixturePrivateKey,
    $FixturePublicKey
  )

  Invoke-InstallBatWithInput -Arguments $InstallArgs -InputLines $InputLines

  if ($script:LastInstallExitCode -ne 0) {
    throw "Prompted setup failed: $(Get-InstallFailureSummary)"
  }

  $CwrgenCmd = Join-Path $PromptInstallPrefix 'bin\cwrgen.cmd'
  if (-not (Test-Path -LiteralPath $CwrgenCmd)) {
    throw "Prompted setup did not install CWRGen: $CwrgenCmd"
  }

  $GitEmail = & 'C:\Program Files\Git\cmd\git.exe' config --global user.email
  if ($GitEmail -ne 'prompt@example.test') {
    throw "Prompted setup did not configure expected Git email. Actual: $GitEmail"
  }

  Write-Log 'Prompted setup-environment test passed.'
}

function Complete-SandboxRun {
  param([string]$Status)

  Set-Content -LiteralPath $StatusPath -Value $Status -Encoding ASCII

  if ($KeepOpen) {
    Read-Host 'Press Enter to close this Sandbox test session'
    return
  }

  if ($NoShutdown) {
    return
  }

  shutdown.exe /s /t 8 /c 'CWRGen Windows Sandbox smoke test completed.' | Out-Null
}

New-Item -ItemType Directory -Force -Path $WorkRoot, $LogDir | Out-Null
Remove-Item -LiteralPath $StatusPath -Force -ErrorAction SilentlyContinue
$TranscriptStarted = $false

try {
  Start-Transcript -LiteralPath $TranscriptPath -Force | Out-Null
  $TranscriptStarted = $true

  Write-Log "Mode: $Mode"
  Assert-SourceTree

  $RunDefault = $Mode -eq 'all' -or $Mode -eq 'both'

  if ($RunDefault -or $Mode -eq 'missing-git-bash') {
    Invoke-MissingGitBashTest
  }

  if ($RunDefault -or $Mode -eq 'auto-install') {
    Invoke-AutoInstallTest
  }

  if ($RunDefault -or $Mode -eq 'setup-options') {
    Invoke-SetupOptionsTest
  }

  if ($RunDefault -or $Mode -eq 'check-only') {
    Invoke-CheckOnlyTest
  }

  if ($Mode -eq 'setup-prompts') {
    Invoke-SetupPromptsTest
  }

  Write-Log 'PASS'
  Complete-SandboxRun 'PASS'
}
catch {
  Write-Log "FAIL: $($_.Exception.Message)"
  Set-Content -LiteralPath $StatusPath -Value "FAIL: $($_.Exception.Message)" -Encoding ASCII
  if ($KeepOpen) {
    Read-Host 'Press Enter to close this failed Sandbox test session'
  }
  elseif ($NoShutdown) {
    Write-Log 'NoShutdown was set; leaving this Windows test session open.'
  }
  else {
    shutdown.exe /s /t 30 /c 'CWRGen Windows Sandbox smoke test failed. Check mapped logs.' | Out-Null
  }
  exit 1
}
finally {
  if ($TranscriptStarted) {
    Stop-Transcript | Out-Null
  }
}
