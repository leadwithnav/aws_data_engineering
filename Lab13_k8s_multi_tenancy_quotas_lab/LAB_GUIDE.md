# Lab Guide: Multi-Tenancy & Quotas — Namespaces, RBAC, ResourceQuota & LimitRange

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

## Step-by-Step Hands-On Verification Guide

### Step 1: Multi-Tenant Namespaces
Create the isolated development namespace, deploy a test workload, and verify cross-namespace isolation:

```bash
# 1. Create the isolated namespace
kubectl create namespace analytics-dev

# 2. Deploy a test pod inside analytics-dev
kubectl run dev-nginx --image=nginx:alpine -n analytics-dev

# 3. Verify pod status inside analytics-dev
kubectl get pods -n analytics-dev

# 4. Verify isolation (pod is NOT visible in default namespace)
kubectl get pods -n default
```

---

### Step 2: RBAC Roles & RoleBindings Security
Configure granular permissions for service accounts and verify access rules:

```bash
# 1. Create the target ServiceAccount
kubectl create serviceaccount spark-dev-sa -n analytics-dev

# 2. Apply Role & RoleBinding manifest
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: developer-role
  namespace: analytics-dev
rules:
  - apiGroups: [""]
    resources: ["pods", "pods/log", "services", "configmaps"]
    verbs: ["get", "list", "watch", "create", "delete"]
  - apiGroups: ["batch"]
    resources: ["jobs"]
    verbs: ["get", "list", "create", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: developer-binding
  namespace: analytics-dev
subjects:
  - kind: ServiceAccount
    name: spark-dev-sa
    namespace: analytics-dev
roleRef:
  kind: Role
  name: developer-role
  apiGroup: rbac.authorization.k8s.io
EOF

# 3. Test Allowed Action (Creating pods)
kubectl auth can-i create pods --as=system:serviceaccount:analytics-dev:spark-dev-sa -n analytics-dev
# Expected Output: yes

# 4. Test Forbidden Action (Deleting namespaces)
kubectl auth can-i delete namespaces --as=system:serviceaccount:analytics-dev:spark-dev-sa
# Expected Output: no
```

---

### Step 3: Namespace ResourceQuota Enforcement
Cap aggregate namespace resource consumption and test quota breach rejection:

```bash
# 1. Apply ResourceQuota manifest (Max 2 vCPUs, 2GiB RAM, 5 Pods)
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
    limits.cpu: "4"
    limits.memory: "4Gi"
    pods: "5"
EOF

# 2. Describe ResourceQuota consumption
kubectl describe resourcequota dev-quota -n analytics-dev

# 3. Deploy valid pod fitting within quota
kubectl run valid-pod --image=nginx:alpine --requests="cpu=200m,memory=256Mi" -n analytics-dev

# 4. Test Quota Breach Rejection (Requesting 10 vCPUs exceeds quota)
kubectl run giant-pod --image=nginx:alpine --requests="cpu=10" -n analytics-dev
# Expected Output: Error from server (Forbidden): pods "giant-pod" is forbidden: exceeded quota: dev-quota
```

---

### Step 4: Container LimitRange Default Injection
Inject default resource requests automatically into unconfigured pod specs:

```bash
# 1. Apply LimitRange manifest
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

# 2. Describe LimitRange rules
kubectl describe limitrange dev-limit-range -n analytics-dev

# 3. Test Default Injection (Deploy pod WITHOUT explicit resources)
kubectl run auto-injected-pod --image=nginx:alpine -n analytics-dev

# 4. Inspect pod spec to verify LimitRange injected 100m CPU / 128Mi RAM requests
kubectl get pod auto-injected-pod -n analytics-dev -o yaml | grep -A 3 "requests:"
```

---

### Step 5: Clean Up Resources
```bash
kubectl delete namespace analytics-dev
```
