FROM redis:8

COPY --from=redislabs/redisgears:edge /build/target/release/ /usr/local/lib/redis/modules/rg
RUN apt-get update && apt-get install curl -y && curl http://nz2.archive.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.1-1ubuntu2.1~18.04.23_amd64.deb -o /tmp/libssl1.1_1.1.1-1ubuntu2.1~18.04.23_amd64.deb
RUN dpkg -i /tmp/libssl1.1_1.1.1-1ubuntu2.1~18.04.23_amd64.deb
WORKDIR /data
ENTRYPOINT [ "redis-server", "/redis.conf" ]