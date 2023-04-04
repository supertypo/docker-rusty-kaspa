FROM rust:1.68-alpine3.17 AS builder

ARG REPO_DIR

RUN apk --no-cache add \
  musl-dev \
  protobuf-dev \
  g++ \
  clang15-dev \
  linux-headers \
  wasm-pack \
  git

RUN rustup component add rustfmt

COPY "$REPO_DIR" /rusty-kaspa

WORKDIR /rusty-kaspa

ENV RUSTFLAGS="-C target-feature=-crt-static"

RUN cargo build --workspace --release


FROM alpine AS rusty

ARG REPO_URL
ARG RUSTY_VERSION

ENV REPO_URL="$REPO_URL" \
  RUSTY_VERSION="$RUSTY_VERSION" \
  RUSTY_UID=50051 \
  PATH=/app:$PATH

RUN apk --no-cache add \
  libgcc \
  libstdc++ \
  dumb-init

RUN addgroup -S -g $RUSTY_UID rusty \
  && adduser -h /app -S -D -g '' -G rusty -u $RUSTY_UID rusty

USER rusty

ENTRYPOINT ["/usr/bin/dumb-init", "--"]


FROM rusty AS kaspad

COPY --from=builder /rusty-kaspa/target/release/kaspad /app

CMD kaspad --help


FROM rusty AS kaspa-wrpc-proxy

COPY --from=builder /rusty-kaspa/target/release/kaspa-wrpc-proxy /app

CMD kaspa-wrpc-proxy --help

