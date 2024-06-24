#!/bin/sh
set -ex

# Find which member of the Stateful Set this pod is running
# e.g. "redis-cluster-0" -> "0"
PET_ORDINAL=$(cat /etc/podinfo/pod_name | rev | cut -d- -f1 | rev)
MY_SHARD=$(($PET_ORDINAL % $NUM_SHARDS))

redis-server /conf/redis.conf &

# TODO: Wait until redis-server process is ready
sleep 1

if [ $PET_ORDINAL -lt $NUM_SHARDS ]; then
  # Set up primary nodes. Divide slots into equal(ish) contiguous blocks
  NUM_SLOTS=$(( 16384 / $NUM_SHARDS ))
  REMAINDER=$(( 16384 % $NUM_SHARDS ))
  START_SLOT=$(( $NUM_SLOTS * $MY_SHARD + ($MY_SHARD < $REMAINDER ? $MY_SHARD : $REMAINDER) ))
  END_SLOT=$(( $NUM_SLOTS * ($MY_SHARD+1) + ($MY_SHARD+1 < $REMAINDER ? $MY_SHARD+1 : $REMAINDER) - 1 ))

  PEER_IP=$(perl -MSocket -e "print inet_ntoa(scalar(gethostbyname(\"redis-cluster-0.redis-cluster.$POD_NAMESPACE.svc.cluster.local\")))")
  redis-cli cluster meet $PEER_IP 6379
  redis-cli cluster addslots $(seq $START_SLOT $END_SLOT)
else
  # Set up a replica
  PEER_IP=$(perl -MSocket -e "print inet_ntoa(scalar(gethostbyname(\"redis-cluster-$MY_SHARD.redis-cluster.$POD_NAMESPACE.svc.cluster.local\")))")
  redis-cli --cluster add-node localhost:6379 $PEER_IP:6379 --cluster-slave
fi

wait