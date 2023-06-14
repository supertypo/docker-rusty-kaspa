##
# builder image
##
FROM rust:1-alpine AS builder

ARG REPO_DIR

RUN apk --no-cache add \
  musl-dev \
  protobuf-dev \
  g++ \
  clang15-dev \
  linux-headers \
  wasm-pack

RUN rustup component add rustfmt

COPY "$REPO_DIR" /rusty-kaspa

WORKDIR /rusty-kaspa

ENV RUSTFLAGS="-C target-feature=-crt-static" \
  CARGO_REGISTRIES_CRATES_IO_PROTOCOL="sparse"

RUN cargo build --workspace --release

##
# base runtime image
##
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


RUN mkdir -p /app/data/ && \
  addgroup -S -g $RUSTY_UID rusty && \
  adduser -h /app/data -S -D -g '' -G rusty -u $RUSTY_UID rusty

USER rusty

ENTRYPOINT ["/usr/bin/dumb-init", "--"]

##
# kaspad image
##
FROM rusty AS kaspad

EXPOSE 16111 16110 17110 18110
VOLUME /app/data

COPY --from=builder /rusty-kaspa/target/release/kaspad /app

CMD kaspad --nologfiles --utxoindex

##
# kaspa-wrpc-proxy image
##
FROM rusty AS kaspa-wrpc-proxy

COPY --from=builder /rusty-kaspa/target/release/kaspa-wrpc-proxy /app

CMD kaspa-wrpc-proxy --help

##
# kaspa-wallet-cli-native image
##
FROM rusty AS kaspa-wallet-cli-native

COPY --from=builder /rusty-kaspa/target/release/kaspa-wallet-cli-native /app

CMD kaspa-wallet-cli-native --help

##
# simpa image
##
FROM rusty AS simpa

COPY --from=builder /rusty-kaspa/target/release/simpa /app

CMD simpa --help

##
# rothschild image
##
FROM rusty AS rothschild

COPY --from=builder /rusty-kaspa/target/release/rothschild /app

CMD rothschild --help

