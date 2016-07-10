#!/bin/sh
set -e

# Find which member of the PetSet this pod is running
# e.g. "redis-cluster-0" -> "0"
PET_ORDINAL=$(cat /etc/podinfo/pod_name | cut -d- -f3)

redis-server /conf/redis.conf &

# TODO: Wait until redis-server process is ready
sleep 1

if [ $PET_ORDINAL = "0" ]; then
  # The first member of the cluster should control all slots initially
  echo "Bootstrapping this cluster node with all cluster slots..."
  redis-cli cluster addslots $(seq 0 16383)
else
  # TODO: Get list of peers using the peer finder using an init container
  PEER_IP=$(perl -MSocket -e 'print inet_ntoa(scalar(gethostbyname("redis-cluster-0.redis-cluster.default.svc.cluster.local")))')
 
  # TODO: Make sure the node we're initializing is not already a master (it may be a recovering node)
  redis-cli cluster meet $PEER_IP 6379
  sleep 1
  
  #echo redis-cli --csv cluster slots
  #redis-cli --csv cluster slots

  # Become the slave of a random master node
  MASTER_ID=$(redis-cli --csv cluster slots | cut -d, -f 5 | sed -e 's/^"//'  -e 's/"$//')
  redis-cli cluster replicate $MASTER_ID
fi

wait

