# Redis Cluster on Kubernetes

This module is intended to simplify the creation and operation of a Redis Cluster deployment in Kubernetes.
I don't recommend that you run this in production - it's just meant to be an illustrative example of a nontrivial Stateful Set deployment.

## Requirements

- Kubernetes 1.17.0+
- Minikube to run the module locally

## How it works

These directions assume some familiarity with [Redis Cluster](http://redis.io/topics/cluster-tutorial). 

When you create the resources in Kubernetes, it will create a 6-member (the minimum recommended size) [Stateful Set](https://kubernetes.io/docs/concepts/workloads/controllers/statefulsets/) cluster where members 0-2 are master nodes and all other members are replicas.

## Testing it out

To launch the cluster, have Kubernetes create all the resources in redis-cluster.yml:

```
$ kubectl create -f redis-cluster.yml
service/redis-cluster created
configmap "redis-cluster-config" configured
poddisruptionbudget.policy/redis-cluster-pdb created
statefulset.apps/redis-cluster created
```

Wait a bit for the service to initialize.

Once all the pods are initialized, you can see that Pod "redis-cluster-0" became the cluster master with the other nodes as slaves.

```
$ kubectl exec redis-cluster-0 -- redis-cli cluster nodes
Defaulted container "redis-cluster" out of: redis-cluster, init-redis-cluster (init)
532505ce41c64ddf4aff143406eb90424c29c138 10.1.0.136:6379@16379 myself,master - 0 1642662784000 1 connected 0-5461
1f188afd5f2a228320cc43753e4b6a1c01c32445 10.1.0.139:6379@16379 slave 532505ce41c64ddf4aff143406eb90424c29c138 0 1642662785392 1 connected
07939f1e633cd3538f8730017aa5ce1d0f8ba680 10.1.0.140:6379@16379 slave de3b3a6d02c81f4104566828e8a523b46e31cd02 0 1642662785000 0 connected
de3b3a6d02c81f4104566828e8a523b46e31cd02 10.1.0.137:6379@16379 master - 0 1642662784386 0 connected 5462-10922
c53e989fa503b04ecc7c651f448a7fc07ac3c975 10.1.0.138:6379@16379 master - 0 1642662786399 2 connected 10923-16383
a43a4a9d81ae095bfdd373ed2c9aebbe958d086a 10.1.0.141:6379@16379 slave c53e989fa503b04ecc7c651f448a7fc07ac3c975 0 1642662784000 2 connected
```

Also, you should be able to use redis-cli to connect to a cluster node we just created
```
$ kubectl exec -it redis-cluster-0 -- redis-cli
```

You can also check the slot configuration here:
```
$ kubectl exec redis-cluster-0 -- redis-cli --cluster check localhost 6379
Defaulted container "redis-cluster" out of: redis-cluster, init-redis-cluster (init)
localhost:6379 (55a74f86...) -> 0 keys | 5462 slots | 1 slaves.
10.1.0.126:6379 (f5b39569...) -> 0 keys | 5461 slots | 1 slaves.
10.1.0.125:6379 (742cf86e...) -> 0 keys | 5461 slots | 1 slaves.
[OK] 0 keys in 3 masters.
0.00 keys per slot on average.
>>> Performing Cluster Check (using node localhost:6379)
M: 55a74f86cf241a90f66a94a6c1789e031adbcc0c localhost:6379
   slots:[0-5461] (5462 slots) master
   1 additional replica(s)
M: f5b39569a75fe72cb16e207f2947d22c625a39ab 10.1.0.126:6379
   slots:[10923-16383] (5461 slots) master
   1 additional replica(s)
S: ddea6fbe8baa7938504f9f1ff503f0f190b49bc3 10.1.0.127:6379
   slots: (0 slots) slave
   replicates 55a74f86cf241a90f66a94a6c1789e031adbcc0c
M: 742cf86e53a93473d17d352d2100b7db9dc61b72 10.1.0.125:6379
   slots:[5462-10922] (5461 slots) master
   1 additional replica(s)
S: 054f92cfb064e5cd762e466799311fbc21228049 10.1.0.128:6379
   slots: (0 slots) slave
   replicates 742cf86e53a93473d17d352d2100b7db9dc61b72
S: ccc463f1aa52c9afd12aa945d7869c2a44f81c9d 10.1.0.129:6379
   slots: (0 slots) slave
   replicates f5b39569a75fe72cb16e207f2947d22c625a39ab
[OK] All nodes agree about slots configuration.
>>> Check for open slots...
>>> Check slots coverage...
[OK] All 16384 slots covered.
```

To add more nodes to the cluster, you can simply use normal stateful set scaling:
```
kubectl scale -n default statefulset redis-cluster --replicas=12
```
Newly-created nodes will join the cluster as replicas.


To clean this mess off your Minikube VM:
```
$ kubectl delete service,statefulsets redis-cluster
$ kubectl delete configmaps redis-cluster-config
$ kubectl delete poddisruptionbudgets.policy redis-cluster-pd

# To prevent potential data loss, deleting a statefulset doesn't delete the pods. Gotta do that manually.
$ kubectl delete pod redis-cluster-0 redis-cluster-1 redis-cluster-2 redis-cluster-3 redis-cluster-4 redis-cluster-5
```

## TODO
- Add documentation for common Redis Cluster operations: adding nodes, resharding, deleting nodes
- Test some failure scenarios
- Use a persistentvolume to store backup files
- Create a ScheduledJob to do automated backups once [this feature](https://github.com/antirez/redis/issues/2463) is finished.
- Make it easier to assign new masters
- Cluster members should check whether nodes.conf exists and if so, skip pod initialization.
