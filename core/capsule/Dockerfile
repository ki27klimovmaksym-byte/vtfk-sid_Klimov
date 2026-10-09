FROM rust:1.79 AS build

WORKDIR /workspace

COPY core/sid/Cargo.toml core/sid/Cargo.lock ./core/sid/

WORKDIR /workspace/core/sid

RUN mkdir -p src \
    && printf 'fn main() {}\n' > src/main.rs \
    && cargo build --release \
    && rm -rf src

COPY core/sid/src ./src

RUN cargo build --release

FROM debian:12-slim

COPY --from=build /workspace/core/sid/target/release/sid-core /usr/local/bin/sid-core

CMD ["sid-core"]