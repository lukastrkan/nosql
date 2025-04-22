FROM ubuntu:22.04 AS base
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y git build-essential python3 python3-pip cmake libssl-dev cargo

WORKDIR /tmp
RUN git clone --recursive --branch v7.99.90 https://github.com/RediSearch/RediSearch
WORKDIR /tmp/RediSearch
RUN make build COORD=oss


FROM redis/redis-stack-server
COPY --from=base /tmp/RediSearch/bin/linux-x64-release/search-community/redisearch.so /opt/redis-stack/lib/redisearch.so
COPY --from=base /usr/lib/x86_64-linux-gnu/libcrypto.so.1.1 /usr/lib/x86_64-linux-gnu/libcrypto.so.1.1
COPY --from=base /usr/lib/x86_64-linux-gnu/libssl.so.1.1 /usr/lib/x86_64-linux-gnu/libssl.so.1.1


LABEL org.opencontainers.image.source=https://github.com/lukastrkan/nosql
LABEL org.opencontainers.image.description="Redis stack server with OSS search coordinator"
LABEL org.opencontainers.image.licenses=MIT
