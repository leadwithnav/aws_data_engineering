# Lab 12: EKS & EMR Resource Management — Who Manages What?

## Executive Summary
This lab explains the 5-layer resource management stack when running Apache Spark workloads on Amazon EKS and EMR on EKS, complete with hands-on `minikube` & `kubectl` verification commands.

---

## Component Responsibility Matrix

| Component Layer | Responsibility | Key Configurations & Actions |
| :--- | :--- | :--- |
| **1. Apache Spark** | Decides how many executors are needed via **Spark Dynamic Allocation** and stage workload calculations. | `spark.dynamicAllocation.enabled=true`<br>`spark.executor.instances` |
| **2. EMR Virtual Cluster** | Acts as a **logical boundary**, mapping to Kubernetes namespaces and restricting namespace resource quotas. | `aws emr-containers create-virtual-cluster`<br>`ResourceQuota` in namespace |
| **3. Kubernetes (kube-scheduler)** | Schedules **Driver and Executor Pods** onto nodes based on requested CPU and Memory vs allocatable capacity. | `spark.kubernetes.driver.request.cores`<br>`spark.kubernetes.executor.request.cores` |
| **4. Cluster Autoscaler / Karpenter** | Dynamically **adds or removes EC2 nodes** when pods are in `Pending` state due to insufficient CPU/Memory. | `NodePool` / `EC2NodeClass` (Karpenter)<br>`eksctl scale nodegroup` |
| **5. EC2 Compute Nodes** | Provides physical or virtual hardware **CPU cores, Memory (RAM), and EBS volume storage**. | Instance types: `m5.xlarge`, `t3.medium`<br>Node Allocatable math |

---

## Hands-On Minikube & Kubectl Testing Commands

```bash
# 1. Start Minikube Cluster
minikube start --cpus 2 --memory 4096

# 2. Create Test Namespace
kubectl create namespace spark-resource-test

# 3. Apply ResourceQuota to Restrict Namespace Resources
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: test-quota
  namespace: spark-resource-test
spec:
  hard:
    requests.cpu: "2"
    requests.memory: "2Gi"
    pods: "5"
EOF

# 4. Verify Active Quota
kubectl get resourcequota -n spark-resource-test

# 5. Deploy Valid Pod (100m CPU = 0.1 vCPU) -> Status: Running
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: valid-pod
  namespace: spark-resource-test
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    resources:
      requests:
        cpu: "100m"
        memory: "128Mi"
EOF

kubectl get pods -n spark-resource-test

# 6. Deploy Oversized Pod (10 vCPUs) -> Status: Pending (FailedScheduling)
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: oversized-pod
  namespace: spark-resource-test
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    resources:
      requests:
        cpu: "10"
        memory: "1Gi"
EOF

# 7. Inspect Scheduling Failure Reason
kubectl describe pod oversized-pod -n spark-resource-test
# Output: Warning FailedScheduling 0/1 nodes available: 1 Insufficient cpu.

# 8. Clean Up Test Namespace
kubectl delete namespace spark-resource-test
```
