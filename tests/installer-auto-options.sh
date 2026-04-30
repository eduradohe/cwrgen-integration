#!/usr/bin/env bash
set -euo pipefail

export HOME=/root
export CWGEN_SOURCE="${CWGEN_SOURCE:-/workspace/cwgen}"

mkdir -p "$HOME/test-keys"
ssh-keygen -t ed25519 -N "" -C "edge@example.test" -f "$HOME/test-keys/id_ed25519" >/dev/null

"$CWGEN_SOURCE/install" \
  --prefix /opt/cwgen-edge \
  --setup-environment \
  --non-interactive \
  --setup-package-manager dnf \
  --setup-git-user-name "Edge Tester" \
  --setup-git-user-email edge@example.test \
  --setup-ssh-private-key "$HOME/test-keys/id_ed25519" \
  --setup-ssh-public-key "$HOME/test-keys/id_ed25519.pub" \
  --force-config \
  --no-update-profile

test -x /opt/cwgen-edge/bin/cwrgen
test "$(git config --global user.email)" = "edge@example.test"
test -f "$HOME/.ssh/id_ed25519"
