FROM redis:8
WORKDIR /data
ENTRYPOINT [ "redis-server", "/redis.conf" ]