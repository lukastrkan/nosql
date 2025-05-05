from ubuntu:24.04 as builder

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y sudo && sudo apt-get install -y --no-install-recommends ca-certificates wget dpkg-dev gcc g++ libc6-dev libssl-dev make git cmake python3 python3-pip python3-venv python3-dev unzip rsync clang automake autoconf libtool

WORKDIR /tmp

RUN wget -O redis-8.0.0.tar.gz https://github.com/redis/redis/archive/refs/tags/8.0.0.tar.gz
RUN tar xvf redis-8.0.0.tar.gz && rm redis-8.0.0.tar.gz && mv /tmp/redis-8.0.0 /redis
WORKDIR /redis

RUN export BUILD_TLS=yes BUILD_WITH_MODULES=yes INSTALL_RUST_TOOLCHAIN=yes DISABLE_WERRORS=yes && \
    make -j "$(nproc)" all

RUN make install

FROM ubuntu:24.04
COPY --from=builder /usr/local/bin/ /usr/local/bin/
#copy modules
COPY --from=builder /redis/modules/*/*.so /usr/local/lib/

ENTRYPOINT [ "redis-server", "/redis.conf" ]