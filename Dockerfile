##
# builder image
##
FROM rust:1.81-alpine AS builder

RUN apk --no-cache add \
  musl-dev \
  protobuf-dev \
  g++ \
  clang15-dev \
  linux-headers \
  wasm-pack \
  openssl-dev

RUN rustup component add rustfmt

ARG REPO_DIR
COPY "$REPO_DIR" /rusty-kaspa

WORKDIR /rusty-kaspa

ENV RUSTFLAGS="-C target-feature=-crt-static" \
  CARGO_REGISTRIES_CRATES_IO_PROTOCOL="sparse"

RUN cargo fetch

# Patch missing include in librocksdb-sys-0.16.0+8.10.0
RUN sed -i '1i #include <cstdint>' $(find /usr/local/cargo/registry/src/ -path "*/librocksdb-sys-0.16.0+8.10.0/*/offpeak_time_info.h")

# Remove vendored openssl (for now)
RUN sed -i 's/openssl .*\["vendored"\] }//' $(find . -name Cargo.toml)

ARG ARTIFACTS
RUN \
  for artifact in $ARTIFACTS; do \
    cargo build --release --bin $artifact; \
  done

##
# base runtime image
##
FROM alpine AS rusty

ARG REPO_URL
ARG RUSTY_VERSION

ENV REPO_URL="$REPO_URL" \
  RUSTY_VERSION="$RUSTY_VERSION" \
  RUSTY_USER=kaspa \
  RUSTY_HOME=/app/data \
  RUSTY_UID=50051 \
  PATH=/app:$PATH

RUN apk --no-cache add \
  libgcc \
  libstdc++ \
  bind-tools \
  su-exec \
  grep

RUN mkdir -p $RUSTY_HOME && \
  addgroup -S -g $RUSTY_UID $RUSTY_USER && \
  adduser -h $RUSTY_HOME -S -D -g '' -G $RUSTY_USER -u $RUSTY_UID $RUSTY_USER

##
# kaspad image
##
FROM supertypo/kaspad:latest AS golang-kaspad
FROM rusty AS kaspad

EXPOSE 16111 16110 17110 18110
VOLUME /app/data

COPY ./entrypoint.sh /app/

ENTRYPOINT ["entrypoint.sh"]

COPY --from=golang-kaspad /app/kaspactl /app
COPY --from=builder /rusty-kaspa/target/release/kaspad /app

CMD ["kaspad", "--yes", "--nologfiles", "--disable-upnp", "--utxoindex", "--rpclisten=0.0.0.0:16110", "--rpclisten-borsh=0.0.0.0:17110", "--rpclisten-json=0.0.0.0:18110"]

##
# kaspa-wrpc-proxy image
##
FROM rusty AS kaspa-wrpc-proxy

COPY --from=builder /rusty-kaspa/target/release/kaspa-wrpc-proxy /app

USER kaspa

CMD ["kaspa-wrpc-proxy", "--help"]

##
# kaspa-wallet-cli-native image
##
FROM rusty AS kaspa-wallet-cli-native

COPY --from=builder /rusty-kaspa/target/release/kaspa-wallet-cli-native /app

USER kaspa

CMD ["kaspa-wallet-cli-native", "--help"]

##
# simpa image
##
FROM rusty AS simpa

COPY --from=builder /rusty-kaspa/target/release/simpa /app

USER kaspa

CMD ["simpa", "--help"]

##
# rothschild image
##
FROM rusty AS rothschild

COPY --from=builder /rusty-kaspa/target/release/rothschild /app

USER kaspa

CMD ["rothschild", "--help"]

