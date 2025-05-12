#!/bin/bash

docker compose down

echo "❗ POZOR: Tento skript smaže všechny data složky Redis clusteru!"
read -p "Chceš opravdu pokračovat? (y/n): " potvrzeni

if [ "$potvrzeni" != "y" ]; then
  echo "Zrušeno."
  exit 0
fi

rm -r ./data/redis-*/data/*

rm ./data/cluster/cluster-initialized

echo "✅ Hotovo. Všechna data byla smazána."

docker compose up -d 
docker compose logs -f