# Lab 10: Scheduling Workloads on Multi-Node Kubernetes using Node Affinity

## Executive Summary
This lab covers **Kubernetes Node Affinity** (`nodeAffinity`) to control physical pod scheduling across a 2-node local cluster (`minikube` and `minikube-m02`). You will label nodes for dedicated workload tiers (`tier=frontend` and `tier=backend`), deploy an **httpd** web server on node 1 and a **mongodb** database on node 2, and learn how Apache Spark driver and executor pods utilize node affinity in enterprise EKS environments.

---

## Architecture Overview

| Node Name | Assigned Label | Target Workload Pod | Pod Image | Target Port |
| :--- | :--- | :--- | :--- | :--- |
| **`minikube`** (Node 1) | `tier=frontend` | `httpd-frontend` | `httpd:alpine` | Port 80 |
| **`minikube-m02`** (Node 2) | `tier=backend` | `mongodb-backend` | `mongo:latest` | Port 27017 |

---

## Step 1: Start a 2-Node Minikube Cluster

Start a 2-node local cluster using the Docker driver:

### 1.1 Start Cluster
```powershell
# Stop and delete any existing cluster to prevent conflicts
minikube delete

# Start a new 2-node cluster
minikube start --nodes=2 --cpus=2 --memory=1800 --driver=docker
```

### 1.2 Inspect Active Nodes
```powershell
kubectl get nodes
```
*Expected Output:*
```text
NAME           STATUS   ROLES           AGE   VERSION
minikube       Ready    control-plane   1m    v1.29.0
minikube-m02   Ready    <none>          45s   v1.29.0
```

---

## Step 2: Assign Tier Labels to Nodes

Attach key-value metadata labels to each worker node to define workload placement targets:

```powershell
# 1. Label Node 1 (minikube) as frontend tier
kubectl label nodes minikube tier=frontend

# 2. Label Node 2 (minikube-m02) as backend tier
kubectl label nodes minikube-m02 tier=backend

# 3. Verify node labels
kubectl get nodes -L tier
```

---

## Step 3: Deploy Workloads with Node Affinity

### 3.1 Frontend Web Server Manifest (`manifests/httpd-frontend-pod.yaml`)
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: httpd-frontend
  labels:
    app: httpd-frontend
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: tier
                operator: In
                values:
                  - frontend
  containers:
    - name: httpd
      image: httpd:alpine
      ports:
        - containerPort: 80
```

### 3.2 Backend Database Manifest (`manifests/mongodb-backend-pod.yaml`)
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: mongodb-backend
  labels:
    app: mongodb-backend
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: tier
                operator: In
                values:
                  - backend
  containers:
    - name: mongodb
      image: mongo:latest
      ports:
        - containerPort: 27017
```

### 3.3 Apply Manifests & Verify Node Placement
```powershell
# Apply httpd frontend pod (targets tier=frontend -> minikube)
kubectl apply -f manifests/httpd-frontend-pod.yaml

# Apply mongodb backend pod (targets tier=backend -> minikube-m02)
kubectl apply -f manifests/mongodb-backend-pod.yaml

# Verify physical pod node placement
kubectl get pods -o wide
```

*Expected Output:*
```text
NAME              READY   STATUS    RESTARTS   AGE   NODE
httpd-frontend    1/1     Running   0          20s   minikube
mongodb-backend   1/1     Running   0          15s   minikube-m02
```

---

## Step 4: Spark Driver & Executor Node Affinity Reference

In enterprise Apache Spark deployments on Amazon EKS or Kubernetes, data engineering teams separate Spark Driver pods from Spark Executor pods using Spark Pod Templates:

### 4.1 Spark Driver Pod Template (`manifests/spark-driver-template.yaml`)
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: spark-driver-template
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: role
                operator: In
                values:
                  - driver
  containers:
    - name: spark-driver
      image: spark-on-eks:latest
```

### 4.2 Spark Executor Pod Template (`manifests/spark-executor-template.yaml`)
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: spark-executor-template
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: role
                operator: In
                values:
                  - executor
  containers:
    - name: spark-executor
      image: spark-on-eks:latest
```

### 4.3 Submitting Spark Jobs with Pod Templates (`spark-submit`)
```bash
spark-submit \
  --master "k8s://https://127.0.0.1:6443" \
  --deploy-mode cluster \
  --name spark-affinity-demo \
  --conf spark.kubernetes.container.image=spark-on-eks:latest \
  --conf spark.kubernetes.driver.podTemplateFile=manifests/spark-driver-template.yaml \
  --conf spark.kubernetes.executor.podTemplateFile=manifests/spark-executor-template.yaml \
  local:///opt/spark/work-dir/spark_app.py
```

---

## Step 5: Teardown Cluster

```powershell
kubectl delete pod httpd-frontend mongodb-backend
minikube stop
```
