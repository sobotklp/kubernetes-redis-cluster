# Redis Cluster on Kubernetes

This k8s module is intended to simplify the creation and operation of a Redis Cluster deployment in Kubernetes.

## Requirements

Kubernetes version 1.3.0+ due to the use of Pet Sets.
Minikube to run the module locally.

## How it works

These directions assume some familiarity with [Redis Cluster](http://redis.io/topics/cluster-tutorial). 

When you create the resources in Kubernetes, it will create a 6-member (the minimum recommended size) [PetSet](http://kubernetes.io/docs/user-guide/petset/) cluster where the first (0th) member is the master and all other members are slaves.
While that's sufficient for getting a cluster up and running, it doesn't distribute cluster slots like you would expect from a real deployment. In addition, automatic failover won't work because the cluster requires at least 2 masters to form a quorum.
## Testing it out

If you don't already have Minikube installed, please follow the [documentation](https://github.com/kubernetes/minikube#installation) to set it up on your local machine.

```
# Start a local Kubernetes cluster
$ minikube start

# Direct kubectl to use Minikube
$ kubectl config use-context minikube
```
To launch the cluster, have Kubernetes create all the resources in redis-cluster.yml:

```
$ kubectl create -f redis-cluster.yml
service "redis-cluster" created
configmap "redis-cluster-config" configured
petset "redis-cluster" created
```

Wait a bit for the service to initialize.

Once all the pods are initialized, you can see that Pod "redis-cluster-0" became the cluster master with the other nodes as slaves.

```
$ kubectl exec -it redis-cluster-0 redis-cli cluster nodes
075293dd82cee03749b983de78cce0ae16b6fc9b 172.17.0.7:6379 slave 4fa0955c6bd58d66ede613bed512a7244c84b34e 0 1468198032209 1 connected
a329f22420fa5ad50184ad8ae4dfcc81092f0e07 172.17.0.5:6379 slave 4fa0955c6bd58d66ede613bed512a7244c84b34e 0 1468198028663 1 connected
ee3e96e11961a24ea705dfdcd53d507bd491a57e 172.17.0.8:6379 slave 4fa0955c6bd58d66ede613bed512a7244c84b34e 0 1468198033717 1 connected
4fa0955c6bd58d66ede613bed512a7244c84b34e 172.17.0.3:6379 myself,master - 0 0 1 connected 0-16383
73c02583f854f65e47a2389419c9a89be3733491 172.17.0.4:6379 slave 4fa0955c6bd58d66ede613bed512a7244c84b34e 0 1468198031701 1 connected
413898a0f8b835e0f8856798300f3451d8211ff4 172.17.0.6:6379 slave 4fa0955c6bd58d66ede613bed512a7244c84b34e 0 1468198032713 1 connected
```

```
# Also, you should be able to use redis-cli to connect to a cluster node we just created
$ kubectl exec -t -i redis-cluster-0 redis-cli
```

# To reshard a cluster

When we started the cluster above, we started with only one master that handles all 16384 slots in the cluster. We'll need to repurpose one of our slaves as a master:

```
# Reset one of the slaves to master
$ kubectl exec -it redis-cluster-2 redis-cli cluster reset soft
# Then rejoin it to the cluster
$ kubectl exec -it redis-cluster-2 redis-cli cluster meet 172.17.0.3 6379
```

Now that we have another free master in the cluster, let's assign it some shards.
```
$ docker run --rm -it redis-trib reshard --from f6752d1c571bf7aa6935597aabd9b0c5c47419bf --to f14dc883290304ad1c580e3db473bbffa8d75404 --slots 8192 --yes 172.17.0.4:6379
```
To clean this mess off your Minikube VM:
```
# Delete service and pet sets
$ kubectl delete service,petsets redis-cluster

# To prevent potential data loss, deleting a pet set doesn't delete the pods. Gotta do that manually.
$ kubectl delete pod redis-cluster-0 redis-cluster-1 redis-cluster-2 redis-cluster-3 redis-cluster-4 redis-cluster-5
```

## TODO
- Add documentation for common Redis Cluster operations: adding nodes, resharding, deleting nodes
- Test some failure scenarios
- livenessProbe
- Create a ScheduledJob to do automated backups once [this feature](https://github.com/antirez/redis/issues/2463) is finished.
- When a pod initializes, use the peer discovery tool to find one or more peers to connect with.
- Create new Docker image to encapsulate pod initialization logic.
- Automated 3-master provisioning
- Make it easier to assign new masters
- Cluster members should check whether nodes.conf exists and if so, skip pod initialization.
