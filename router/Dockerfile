# Hyperswitch router (payments API) for Railway.
# Upstream image, pinned by version and digest. Bump all three pins together
# (router, migrations commit, diesel) and add a CHANGELOG.md entry.

# --- Stage 1: the upstream database migrations and the diesel CLI that runs them
FROM debian:trixie-slim@sha256:a72b4433de1cf7d6bae0c4cee74d0547f58601a643b3375f070c51600d63b6b2 AS tools
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl git xz-utils \
    && rm -rf /var/lib/apt/lists/*

# diesel CLI: upstream runs migrations with `diesel migration run` (justfile, migration-runner image).
ARG DIESEL_VERSION=2.3.5
ARG DIESEL_SHA256=264d6f71426d9cf25ce389d1669ef9a18df0bc8f1807736be76a757843ee1645
RUN curl -fsSL -o /tmp/diesel.tar.xz \
      "https://github.com/diesel-rs/diesel/releases/download/v${DIESEL_VERSION}/diesel_cli-x86_64-unknown-linux-gnu.tar.xz" \
    && echo "${DIESEL_SHA256}  /tmp/diesel.tar.xz" | sha256sum -c - \
    && tar -xJf /tmp/diesel.tar.xz -C /tmp \
    && install -m 0755 /tmp/diesel_cli-x86_64-unknown-linux-gnu/diesel /usr/local/bin/diesel

# Migrations and the reference config from the same release tag as the image.
ARG HYPERSWITCH_TAG=v1.129.0
ARG HYPERSWITCH_COMMIT=cf913c5aaa226e102b257a81a3a53ac841bf45bd
RUN git clone --quiet --depth 1 --branch "${HYPERSWITCH_TAG}" --filter=blob:none --sparse \
      https://github.com/juspay/hyperswitch /src \
    && cd /src \
    && git sparse-checkout set migrations config \
    && test "$(git rev-parse HEAD)" = "${HYPERSWITCH_COMMIT}"

# --- Stage 2: the official router image
FROM juspaydotin/hyperswitch-router:v1.129.0-standalone@sha256:dbbc78845ac1c6dd3cdcc6bd00de11646351b37e2173cca5f32dd723a8021dea

USER root
COPY --from=tools /usr/local/bin/diesel /usr/local/bin/diesel
COPY --from=tools /src/migrations /local/migrations
COPY --from=tools /src/config/docker_compose.toml /local/config/router.toml
COPY --from=tools /src/config/superposition_seed.toml /local/config/superposition_seed.toml
COPY start.sh /usr/local/bin/hyperswitch-start
RUN chmod 0755 /usr/local/bin/hyperswitch-start \
    && touch /local/config/diesel.toml \
    && mkdir -p /local/bin/files \
    && chown app:app /local/bin/files

ENV HYPERSWITCH_VERSION=1.129.0
EXPOSE 8080
# Starts as root only to fix the volume's ownership, then drops to the image's `app` user.
CMD ["/usr/local/bin/hyperswitch-start"]
