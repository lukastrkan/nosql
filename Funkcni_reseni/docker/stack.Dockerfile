FROM ubuntu:22.04 AS base
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y git build-essential python3 python3-pip cmake libssl-dev cargo wget

WORKDIR /tmp
RUN git clone --recursive --branch v2.10.15 https://github.com/RediSearch/RediSearch
WORKDIR /tmp/RediSearch/.install
RUN ./install_boost.sh 1.84.0;
WORKDIR /tmp/RediSearch
RUN make build COORD=oss


FROM redis/redis-stack-server
COPY --from=base /tmp/RediSearch/bin/linux-x64-release/coord-oss/module-oss.so /opt/redis-stack/lib/redisearch.so
