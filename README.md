# Redis Cluster on Kubernetes

This k8s module is intended to simplify the creation and operation of a Redis Cluster deployment in Kubernetes.

## Requirements

Kubernetes version 1.3.0+ due to the use of Pet Sets.

## How it works

When you initially start a Redis cluster, it will initialize the first (0th) member of the cluster as the master and designate all other members as slaves.

## Testing it out

If you don't already have Minikube installed, please follow the [documentation](https://github.com/kubernetes/minikube#installation) to set it up on your local machine.

    # Start a local Kubernetes cluster
    minikube start

    # Direct kubectl to use Minikube
    kubectl config use-context minikube

To launch the cluster, have Kubernetes create all the resources in redis-cluster.yml:

```
kubectl create -f redis-cluster.yml
service "redis-cluster" created
configmap "redis-cluster-config" configured
petset "redis-cluster" created
```

Wait a bit for the service to initialize.

Once all the pods are initialized, you can see that Pod "redis-cluster-0" became the cluster master with the other nodes as slaves.

```
kubectl exec -it redis-cluster-0 redis-cli cluster nodes
13e84b3dcb7a8a1b6cf06331d2954e9875bbdf9f 172.17.0.5:6379 slave f6752d1c571bf7aa6935597aabd9b0c5c47419bf 0 1468130437707 2 connected
f6752d1c571bf7aa6935597aabd9b0c5c47419bf 172.17.0.3:6379 myself,master - 0 0 0 connected 0-16383
f14dc883290304ad1c580e3db473bbffa8d75404 172.17.0.4:6379 slave f6752d1c571bf7aa6935597aabd9b0c5c47419bf 0 1468130437707 1 connected
```

```
# Also, you should be able to use redis-cli to connect to a cluster node we just created
kubectl exec -t -i redis-cluster-0 redis-cli
```

To clean this mess off your Minikube VM:
```
# Delete service and pet sets
kubectl delete service,petsets redis-cluster

# To prevent potential data loss, deleting a pet set doesn't delete the pods. Gotta do that manually.
kubectl delete pod redis-cluster-0 redis-cluster-1 redis-cluster-2
```

## TODO
- Add documentation for common Redis Cluster operations: adding nodes, resharding, deleting nodes
- Test some failure scenarios
- Create a ScheduledJob to do automated backups once [this feature](https://github.com/antirez/redis/issues/2463) is finished.
- Create new Docker image to encapsulate pod initialization logic


