FROM ubuntu 24.04 AS base
ENV TZ=Europe/Prague
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y cargo git
WORKDIR /tmp
RUN git clone --depth 1 --recursive https://github.com/clia/rcproxy
RUN cargo build --all --release

FROM ubuntu:24.04
ENV TZ=Europe/Prague
ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /app
COPY --from=base /tmp/rcproxy/target/release /app

ENTRYPOINT [ "./app/rcproxy" "/app/default.toml"]
