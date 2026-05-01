# CWRGen Integration Harness

This repository contains Docker-based integration tests for CWRGen installation,
configuration, and execution.

The harness creates a local SSH Git server with disposable example repositories,
then runs CWRGen from a separate developer-machine container against real Git
commits. No private repository data is stored here.

## Layout

```text
compose.yaml                         Docker Compose test topology
docker/git-server/                   SSH Git server image and seed script
docker/developer-machine/            Happy-path client image
docker/installer-edge-machine/       Installation edge-case client images
scripts/run-all.sh                   Main local test entrypoint
scripts/windows-ci/                  GitHub Actions Windows smoke harness
scripts/windows-sandbox/             Local Windows Sandbox batch harness
tests/*.sh                           Bash integration tests
```

## Test Topology

- `git-server` exposes bare Git repositories over SSH.
- `developer-machine` installs CWRGen and runs the happy-path evidence flow.
- `installer-edge-*` images are reserved for installation edge cases across lean
  Linux distributions.
- Bash test scripts drive the first integration layer. A Bats wrapper can be
  added later if we want richer test output.

## Running Locally

Copy or checkout the CWRGen repository next to this repository:

```text
../cwrgen
../cwrgen-integration
```

Then run:

```bash
./scripts/run-all.sh
```

To test a different CWRGen checkout:

```bash
CWGEN_SOURCE=/path/to/cwrgen ./scripts/run-all.sh
```

## Windows Batch Tests

Linux installation and execution tests run through Docker. Windows batch tests
run directly on GitHub Actions `windows-latest`, with Windows Sandbox available
for local disposable-machine checks.

The GitHub Actions workflow invokes the CI smoke path like this:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\scripts\windows-ci\run-install-smoke.ps1 -CwgenSource ..\cwrgen
```

GitHub-hosted Windows runners already include Git for Windows, so this path
validates the batch installer and command wrapper against the hosted Windows
runtime. Use the Windows Sandbox harness below for a clean-machine check of the
missing-Git-Bash and installer-download paths, and for local runs that should
not touch your normal Windows profile.

The GitHub Actions workflow checks out the public CWRGen repository directly.

To generate and start the Windows Sandbox smoke test:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\scripts\windows-sandbox\run-install-smoke.ps1 -CwgenSource ..\cwrgen
```

The default mode runs the main Windows batch checks:

- `missing-git-bash`: verifies `install.bat` fails clearly when Git Bash is
  missing and auto-install was not requested.
- `auto-install`: runs `install.bat --install-git-bash`, verifies the installed
  `cwrgen.cmd --help`, and checks the user `PATH` update inside the Sandbox.
- `setup-options`: runs `install.bat --setup-environment --non-interactive`
  with supplied Git identity and SSH key options.
- `check-only`: runs `install.bat --check-only` and verifies no install prefix
  is created.

For the auto-install mode, the harness passes an explicit Git for Windows
installer source to `install.bat`. By default it resolves the latest 64-bit Git
for Windows installer URL from the public GitHub release metadata. For
deterministic or offline runs, provide a local installer fixture instead:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\scripts\windows-sandbox\run-install-smoke.ps1 -GitInstallerPath C:\Downloads\Git-64-bit.exe
```

You can also provide a direct installer URL and optional SHA-256:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\scripts\windows-sandbox\run-install-smoke.ps1 -GitInstallerUrl https://example.com/Git-64-bit.exe -GitInstallerSha256 <hash>
```

Useful options:

```powershell
# Only write the .wsb file, without opening Windows Sandbox.
powershell.exe -ExecutionPolicy Bypass -File .\scripts\windows-sandbox\run-install-smoke.ps1 -GenerateOnly

# Keep the Sandbox open after the test finishes.
powershell.exe -ExecutionPolicy Bypass -File .\scripts\windows-sandbox\run-install-smoke.ps1 -KeepOpen

# Run only one batch-test mode.
powershell.exe -ExecutionPolicy Bypass -File .\scripts\windows-sandbox\run-install-smoke.ps1 -Mode missing-git-bash

# Run the prompted setup flow with stdin-fed answers in a clean Sandbox.
powershell.exe -ExecutionPolicy Bypass -File .\scripts\windows-sandbox\run-install-smoke.ps1 -Mode setup-prompts
```

Sandbox logs and status are written to:

```text
target/windows-sandbox/
```
