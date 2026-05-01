#!/usr/bin/env bash
set -euo pipefail

setup_git_user() {
  if ! id git >/dev/null 2>&1; then
    useradd -m -s /bin/sh git
  fi
  echo 'git:git' | chpasswd

  mkdir -p /home/git/.ssh /srv/git
  cat /tmp/client_key.pub >/home/git/.ssh/authorized_keys
  chown -R git:git /home/git/.ssh /srv/git
  chmod 700 /home/git/.ssh
  chmod 600 /home/git/.ssh/authorized_keys
}

setup_sshd() {
  ssh-keygen -A
  mkdir -p /run/sshd /etc/ssh/sshd_config.d
  {
    echo 'PasswordAuthentication no'
    echo 'PermitRootLogin no'
    echo 'PubkeyAuthentication yes'
    echo 'AllowUsers git'
  } >/etc/ssh/sshd_config.d/cwgen.conf
}

setup_git_user
setup_sshd
su git -c /usr/local/bin/seed-repos.sh

exec /usr/sbin/sshd -D -e
