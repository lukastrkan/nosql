#!/bin/bash

rcli() {
  redis-cli -h redis-1-master -p 6379 "$@"
}

echo "⏳ Čekám na Redis instance..."
sleep 10

INIT_MARKER=/cluster/cluster-initialized

if [ -f "$INIT_MARKER" ]; then
  echo "🔁 Cluster už byl inicializován."
else
  echo "🚀 Vytvářím Redis cluster..."
  yes yes | rcli --cluster create \
    redis-1-master:6379 \
    redis-2-master:6379 \
    redis-3-master:6379 \
    --cluster-replicas 0

  echo "⏳ Čekám na šíření konfigurace..."
  sleep 5

  echo "🔍 Získávám Node ID masterů..."
  ALL_NODES=$(rcli cluster nodes)

  ID_REDIS_1_MASTER=$(echo "$ALL_NODES" | grep 172.28.0.11 | sed -n 1p | awk '{print $1}')
  ID_REDIS_2_MASTER=$(echo "$ALL_NODES" | grep 172.28.0.13 | sed -n 1p | awk '{print $1}')
  ID_REDIS_3_MASTER=$(echo "$ALL_NODES" | grep 172.28.0.15 | sed -n 1p | awk '{print $1}')

  echo "🧩 Master ID:"
  echo "redis-1-master: $ID_REDIS_1_MASTER"
  echo "redis-2-master: $ID_REDIS_2_MASTER"
  echo "redis-3-master: $ID_REDIS_3_MASTER"

  echo "🔗 Připojuji slave nody..."
  rcli --cluster add-node redis-1-slave:6379 redis-1-master:6379 \
    --cluster-slave --cluster-master-id $ID_REDIS_1_MASTER

  rcli --cluster add-node redis-2-slave:6379 redis-2-master:6379 \
    --cluster-slave --cluster-master-id $ID_REDIS_2_MASTER

  rcli --cluster add-node redis-3-slave:6379 redis-3-master:6379 \
    --cluster-slave --cluster-master-id $ID_REDIS_3_MASTER

  echo "✅ Cluster byl vytvořen a repliky nastaveny."  
fi

echo "⏳ Čekám na cluster_state=ok na všech nodech..."

MASTER_NODES=(
  redis-1-master
  redis-2-master
  redis-3-master
)

SLAVE_NODES=(
  redis-1-slave
  redis-2-slave
  redis-3-slave
)

NODES=("${MASTER_NODES[@]}" "${SLAVE_NODES[@]}")


for NODE in "${NODES[@]}"; do
  while true; do
    STATE=$(redis-cli -h "$NODE" -p 6379 cluster info | grep cluster_state | awk -F: '{print $2}' | tr -d '\r')
    if [ "$STATE" = "ok" ]; then
      echo "✅ $NODE: cluster_state=ok"
      break
    else
      echo "⏳ $NODE: čekám..."
      sleep 1
    fi
  done
done

echo "🔄 REFRESHCLUSTER na všech nodech..."

for NODE in "${MASTER_NODES[@]}"; do
  redis-cli -h "$NODE" -p 6379 REDISGEARS_2.REFRESHCLUSTER
done

echo "📥 Nahrávám Gears funkce..."

for NODE in "${NODES[@]}"; do
  echo "🧹 $NODE: odstraňuji staré knihovny..."
  redis-cli -h "$NODE" -p 6379 TFUNCTION DELETE lib > /dev/null 2>&1
  redis-cli -h "$NODE" -p 6379 TFUNCTION DELETE steamlib > /dev/null 2>&1

  echo "⬆️ $NODE: načítám nové knihovny..."
  redis-cli -h "$NODE" -p 6379 -x TFUNCTION LOAD < /libs/lib.js
  redis-cli -h "$NODE" -p 6379 -x TFUNCTION LOAD < /libs/steamlib.js
done

echo "✅ Gears skripty nahrány a topologie obnovena."

if [ ! -f "$INIT_MARKER" ]; then
  echo "📦 Importuji počáteční data..."
  cd /python
  /python/venv/bin/python scripts/load_data.py
fi

touch "$INIT_MARKER"