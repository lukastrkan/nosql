#!/bin/bash

# Nastavení barev pro lepší čitelnost výstupu
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

PASSWORD="strongpassword"

# Funkce pro logování
log() {
    echo -e "${GREEN}[✓]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[!]${NC} $1"
}

error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Hlavní proměnné
REDIS_PORT=6379
INIT_MARKER=/cluster/cluster-initialized

NODES=(
  redis-1
  redis-2
  redis-3
  redis-4
  redis-5
  redis-6
)

# Certifikáty pro TLS
CERT_PATH="/certs"
CA_CERT="${CERT_PATH}/ca.crt"
CLIENT_CERT="${CERT_PATH}/redis.crt"
CLIENT_KEY="${CERT_PATH}/redis.key"

# Funkce pro vytvoření Redis klienta s podporou TLS
redis_cli() {
    local host=$1
    shift  # Odstranění prvního parametru (hostitele)
    
    # Kontrola existence certifikátů
    if [ -f "$CA_CERT" ] && [ -f "$CLIENT_CERT" ] && [ -f "$CLIENT_KEY" ]; then
        # TLS připojení
        redis-cli -h "$host" -p $REDIS_PORT --tls \
            --cert "$CLIENT_CERT" \
            --key "$CLIENT_KEY" \
            --cacert "$CA_CERT" \
            -a $PASSWORD "$@"
    else
        # Standardní připojení
        redis-cli -h "$host" -p $REDIS_PORT -a $PASSWORD "$@"
    fi
}

# Čekání na dostupnost Redis instancí
wait_for_redis() {
    local host=$1
    local max_attempts=60
    local attempt=0

    while [ $attempt -lt $max_attempts ]; do
        if redis_cli "$host" PING | grep -q PONG; then
            log "$host je dostupný"
            return 0
        fi
        
        warn "$host není dostupný, čekám... (pokus $((attempt+1))/$max_attempts)"
        sleep 1
        ((attempt++))
    done

    error "Timeout při čekání na $host"
    return 1
}

# Čekání na všechny instance
wait_for_all_redis() {
    for node in "${NODES[@]}"; do
        wait_for_redis "$node" || return 1
    done
}

# Vytvoření clusteru
create_redis_cluster() {
    log "Zahajuji vytváření Redis clusteru"

    # Příprava parametrů pro cluster create - všechny nody
    CLUSTER_NODES=""
    for node in "${NODES[@]}"; do
        CLUSTER_NODES+=" $node:$REDIS_PORT"
    done

    # Vytvoření clusteru s TLS podporou
    yes yes | redis-cli --cluster create $CLUSTER_NODES --cluster-replicas 1 \
        --tls --cert "$CLIENT_CERT" --key "$CLIENT_KEY" --cacert "$CA_CERT" -a $PASSWORD
    log "Cluster vytvořen"
}

# Kontrola stavu clusteru
check_cluster_state() {
    for node in "${NODES[@]}"; do
        state=$(redis_cli "$node" CLUSTER INFO | grep cluster_state | cut -d: -f2 | tr -d '\r')
        if [ "$state" != "ok" ]; then
            error "$node má nesprávný cluster_state: $state"
            return 1
        fi
    done
    log "Cluster je plně funkční"
    return 0
}

# Hlavní průběh
main() {
    # Kontrola dostupnosti certifikátů
    if [ -f "$CA_CERT" ] && [ -f "$CLIENT_CERT" ] && [ -f "$CLIENT_KEY" ]; then
        log "TLS certifikáty nalezeny, použiji zabezpečené připojení"
    else
        warn "TLS certifikáty nenalezeny, použiji nezabezpečené připojení"
    fi

    # Čekání na dostupnost Redis instancí
    wait_for_all_redis || exit 1

    # Pokud již existuje inicializační marker, cluster už byl vytvořen
    if [ -f "$INIT_MARKER" ]; then
        log "Cluster již byl inicializován"
        check_cluster_state
        exit $?
    fi

    # Vytvoření clusteru
    create_redis_cluster

    # Kontrola stavu clusteru
    check_cluster_state

    # Import dat, pokud ještě neprobíhal
    if [ ! -f "$INIT_MARKER" ]; then
        log "Importuji počáteční data"
        cd /python
        /python/venv/bin/python scripts/load_data.py
    fi

    # Vytvoření inicializačního markeru
    touch "$INIT_MARKER"

    log "Inicializace clusteru dokončena"
}

# Spuštění hlavní funkce
main