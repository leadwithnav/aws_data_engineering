# Lab 12: EKS & EMR Resource Management — Who Manages What?

## Executive Summary
This lab explains the 5-layer resource management stack when running Apache Spark workloads on Amazon EKS and EMR on EKS.

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

## Verification & Commands

```bash
# 1. Check Node Allocatable CPU and Memory
kubectl describe nodes | grep -A 6 "Allocatable:"

# 2. Check Pod Resource Requests & Pending Reasons
kubectl describe pod <POD_NAME>

# 3. Check Namespace Resource Quotas
kubectl get resourcequota -n <NAMESPACE>
```
