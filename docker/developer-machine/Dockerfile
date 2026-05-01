FROM almalinux:9

RUN dnf install -y bash findutils tar gzip openssh-clients procps-ng \
  && dnf clean all

COPY fixtures/keys/id_ed25519 /tmp/client_key
COPY fixtures/keys/id_ed25519.pub /tmp/client_key.pub
COPY tests /tests
COPY scripts /scripts

RUN chmod +x /scripts/*.sh

WORKDIR /workspace

CMD ["/bin/bash"]
