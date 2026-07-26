# Lab 13: Multi-Tenancy & Quotas — Namespaces, RBAC, ResourceQuota & LimitRange

## Executive Summary
This lab covers building secure multi-tenant Kubernetes and Amazon EKS environments using **Namespaces**, **RBAC Roles & RoleBindings**, **ResourceQuota**, and **LimitRange** manifests.

---

## 4 Pillars of Kubernetes Multi-Tenancy

| Component | Manifest Object | Purpose |
| :--- | :--- | :--- |
| **1. Namespaces** | `Namespace` | Virtual cluster partitioning per team/environment (`analytics-dev`, `analytics-prod`). |
| **2. RBAC Security** | `Role` & `RoleBinding` | Granular permission control binding users/service accounts to allowed API actions (verbs). |
| **3. ResourceQuota** | `ResourceQuota` | Aggregate namespace resource ceilings capping total CPU, Memory, and Pod counts. |
| **4. LimitRange** | `LimitRange` | Injects default container CPU/RAM requests and sets min/max container size constraints. |

---

## Hands-On Minikube & Kubectl Verification Workflow

```bash
# 1. Start Minikube cluster
minikube start --cpus 2 --memory 4096

# 2. Create isolated team namespace
kubectl create namespace analytics-dev

# 3. Apply ResourceQuota (2 vCPUs, 2GiB RAM, 5 Pods max)
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: dev-quota
  namespace: analytics-dev
spec:
  hard:
    requests.cpu: "2"
    requests.memory: "2Gi"
    pods: "5"
EOF

# 4. Apply LimitRange (Injects default 100m CPU / 128Mi RAM requests)
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: LimitRange
metadata:
  name: dev-limit-range
  namespace: analytics-dev
spec:
  limits:
    - type: Container
      default:
        cpu: "500m"
        memory: "512Mi"
      defaultRequest:
        cpu: "100m"
        memory: "128Mi"
      max:
        cpu: "2"
        memory: "2Gi"
      min:
        cpu: "50m"
        memory: "64Mi"
EOF

# 5. Verify active quotas and limits
kubectl get resourcequota,limitrange -n analytics-dev

# 6. Test Default Injection: Deploy pod without specifying resources
kubectl run test-pod --image=nginx:alpine -n analytics-dev

# Inspect pod spec to verify injected requests
kubectl get pod test-pod -n analytics-dev -o yaml | grep -A 3 "requests:"

# 7. Test Quota Breach: Deploy pod requesting 10 vCPUs
kubectl run giant-pod --image=nginx:alpine --requests="cpu=10" -n analytics-dev
# Expected: Error from server (Forbidden): pods "giant-pod" is forbidden: exceeded quota: dev-quota

# 8. Clean up
kubectl delete namespace analytics-dev
```
