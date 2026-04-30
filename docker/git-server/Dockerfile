FROM alpine:3.20

RUN apk add --no-cache bash git openssh shadow

COPY docker/git-server/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY docker/git-server/seed-repos.sh /usr/local/bin/seed-repos.sh
COPY fixtures/keys/id_ed25519.pub /tmp/client_key.pub

RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/seed-repos.sh

EXPOSE 22

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
