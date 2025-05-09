from redis.cluster import RedisCluster, ClusterNode

def get_redis_client():
    startup_nodes = [
        ClusterNode(host='172.28.0.11', port=6379),
        ClusterNode(host='172.28.0.13', port=6379),
        ClusterNode(host='172.28.0.15', port=6379),
    ]
    #return RedisCluster(startup_nodes=startup_nodes, decode_responses=True, password='strongpassword')
    return RedisCluster(startup_nodes=startup_nodes, decode_responses=True)
