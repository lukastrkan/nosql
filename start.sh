#!/bin/bash

mkdir -p certs
cd certs

openssl genrsa -out ca.key 4096
openssl req -x509 -new -nodes -sha256 -key ca.key -days 365 -subj '/CN=Redis CA' -out ca.crt

openssl genrsa -out redis.key 2048
openssl req -new -sha256 -subj "/CN=Redis" -key redis.key | \
    openssl x509 -req -sha256 -CA ca.crt -CAkey ca.key -CAserial ca.srl -CAcreateserial -days 365 -out redis.crt


cd ..

docker compose up -d && docker compose logs redis-init -f