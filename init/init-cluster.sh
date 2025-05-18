#!/bin/bash
set -e

# Priznak inicializace
INIT_MARKER=/cluster/cluster-initialized

# Info o Redis nodech
PASSWORD="strongpassword"
NODES=(
  redis-1
  redis-2
  redis-3
  redis-4
  redis-5
  redis-6
)
REDIS_PORT=6379


CERT_PATH="/certs"
CA_CERT="${CERT_PATH}/ca.crt"
CLIENT_CERT="${CERT_PATH}/redis.crt"
CLIENT_KEY="${CERT_PATH}/redis.key"

rcli () {
    local host="$1"
    shift
    redis-cli -h "$host" -p $REDIS_PORT --tls \
        --cert "$CLIENT_CERT" \
        --key "$CLIENT_KEY" \
        --cacert "$CA_CERT" \
        -a $PASSWORD "$@"
}

if [[ -f $INIT_MARKER ]]; then
    echo "Cluster already initialized. Exiting."
    exit 0
else
    echo "Inicializace clusteru"

    CLUSTER_NODES=""
    for node in "${NODES[@]}"; do
        CLUSTER_NODES+=" $node:$REDIS_PORT"
    done

    yes yes | rcli "${NODES[0]}" --cluster create $CLUSTER_NODES --cluster-replicas 1    
    sleep 10

    echo "Cluster inicializovan"

    while true; do
        echo "Cekam na OK stav clusteru"
        CLUSTER_INFO=$(rcli "${NODES[0]}" cluster info)
        echo "Stav clusteru: $CLUSTER_INFO"
        if [[ $CLUSTER_INFO == *"cluster_state:ok"* ]]; then
            echo "Cluster je v poradku"
            break
        else
            echo "Cluster neni v poradku, cekam 5 sekund"
            sleep 5
        fi
    done

    echo "Import dat do clusteru"
    cd /init
    /init/venv/bin/python load_data.py
    echo "Data importovana"

    touch $INIT_MARKER
fi