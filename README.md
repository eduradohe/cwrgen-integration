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
../cwgen
../cwgen-integration
```

Then run:

```bash
./scripts/run-all.sh
```

To test a different CWRGen checkout:

```bash
CWGEN_SOURCE=/path/to/cwgen ./scripts/run-all.sh
```

## Windows Batch Tests

Linux installation and execution tests run through Docker. Windows batch testing
should use a real Windows runner, such as GitHub Actions `windows-latest`, and
later a self-hosted Windows runner or Windows Sandbox for the missing-Git-Bash
auto-install path.
