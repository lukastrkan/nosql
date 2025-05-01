#!/bin/bash

rcli() {
  redis-cli -h redis-1-master -p 6379 -a strongpassword "$@"
}

INIT_MARKER=/cluster/cluster-initialized

if [ -f "$INIT_MARKER" ]; then
  echo "Cluster už byl inicializován."
  exit 0
fi

echo "Čekám na Redis instance..."
sleep 10

echo "Krok 1: Vytvářím Redis cluster s master nody..."
yes yes | rcli --cluster create \
  redis-1-master:6379 \
  redis-2-master:6379 \
  redis-3-master:6379 \
  --cluster-replicas 0

echo "Čekám, než se konfigurace plně rozšíří..."
sleep 5

echo "Krok 2: Získávám Node ID jednotlivých masterů..."

# Získání ID všech master nodů ze stejného cluster výpisu
ALL_NODES=$(rcli cluster nodes)

echo "Všechny nody:"
echo "$ALL_NODES"

ID_REDIS_1_MASTER=$(echo "$ALL_NODES" | grep 172.28.0.11 | sed -n 1p | awk '{print $1}')
ID_REDIS_2_MASTER=$(echo "$ALL_NODES" | grep 172.28.0.13 | sed -n 1p | awk '{print $1}')
ID_REDIS_3_MASTER=$(echo "$ALL_NODES" | grep 172.28.0.15 | sed -n 1p | awk '{print $1}')

echo "Master ID:"
echo "redis-1-master: $ID_REDIS_1_MASTER"
echo "redis-2-master: $ID_REDIS_2_MASTER"
echo "redis-3-master: $ID_REDIS_3_MASTER"

echo "Krok 3: Připojuji slave nody k přesně určeným masterům..."

# Připojí redis-1-slave k redis-1-master
rcli --cluster add-node redis-1-slave:6379 redis-1-master:6379 \
  --cluster-slave --cluster-master-id $ID_REDIS_1_MASTER

# Připojí redis-2-slave k redis-2-master
rcli --cluster add-node redis-2-slave:6379 redis-2-master:6379 \
  --cluster-slave --cluster-master-id $ID_REDIS_2_MASTER

# Připojí redis-3-slave k redis-3-master
rcli --cluster add-node redis-3-slave:6379 redis-3-master:6379 \
  --cluster-slave --cluster-master-id $ID_REDIS_3_MASTER

echo "✅ Redis cluster byl úspěšně vytvořen a repliky přiřazeny ručně."

touch "$INIT_MARKER"
