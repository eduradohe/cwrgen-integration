#!/usr/bin/env bash
set -euo pipefail

export HOME=/root
export CWGEN_SOURCE="${CWGEN_SOURCE:-/workspace/cwgen}"

"$CWGEN_SOURCE/install" \
  --prefix /opt/cwgen-edge \
  --setup-environment \
  --non-interactive \
  --setup-package-manager dnf \
  --setup-git-user-name "Edge Tester" \
  --setup-git-user-email edge@example.test \
  --setup-ssh-private-key /tmp/client_key \
  --setup-ssh-public-key /tmp/client_key.pub \
  --force-config \
  --no-update-profile

test -x /opt/cwgen-edge/bin/cwrgen
test "$(git config --global user.email)" = "edge@example.test"
test -f "$HOME/.ssh/client_key"
