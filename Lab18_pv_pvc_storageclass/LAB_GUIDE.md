# Lab Guide: Kubernetes Persistent Volumes (PV), PVCs, StorageClasses & PostgreSQL Data Persistence

Welcome to **Lab 18: Kubernetes Storage Architecture — PersistentVolumes (PV), PersistentVolumeClaims (PVC), Default StorageClasses (SC), PostgreSQL Data Persistence Verification, and Spark Volume Integration**.

In containerized environments, containers are ephemeral by default. When a pod is deleted, its internal container file system is destroyed. This lab demonstrates how Kubernetes **PersistentVolumeClaims (PVCs)** bind to the cluster's **Default StorageClass** to attach persistent, non-ephemeral storage to pods, guaranteeing 100% data survival across pod crashes, upgrades, and manual pod deletions.

---

## Architectural Storage Workflow

```mermaid
graph TD
    subgraph Kubernetes Storage Abstraction Layer
        SC[Default StorageClass: standard / gp2] -->|Dynamic Provisioner| PV[PersistentVolume: HostPath / EBS]
        PVC[PersistentVolumeClaim: postgres-pvc] -->|Binds to Default SC| PV
    end

    subgraph Workload Layer (PostgreSQL Pod)
        POD[PostgreSQL Pod: postgres-db-xxxx] -->|Mounts PVC to /var/lib/postgresql/data| PVC
        USER[Data Engineer] -->|1. Inserts Data via psql| POD
        KILL[2. Delete Pod: kubectl delete pod] -.->|Destroys Container| POD
        RS[ReplicaSet / Deployment Controller] -->|3. Recreates New Pod| NEW_POD[New PostgreSQL Pod: postgres-db-yyyy]
        NEW_POD -->|4. Re-attaches Same PVC| PVC
        VERIFY[5. Select * from orders] -->|Data Intact 100%!| NEW_POD
    end
```

---

## Storage Architecture Concepts Breakdown

| Storage Concept | Abstraction Level | Primary Function & Responsibility |
| :--- | :--- | :--- |
| **StorageClass (SC)** | Provisioning Policy | Pre-installed cluster policy (e.g. `standard (default)` in Minikube, `gp2` / `gp3` in EKS). Enables **Dynamic Provisioning**. |
| **PersistentVolumeClaim (PVC)** | Developer Storage Request | Requests storage size (e.g. `1Gi`) and access mode (`ReadWriteOnce`). Omitting `storageClassName` automatically binds to the cluster default StorageClass. |
| **PersistentVolume (PV)** | Cluster Infrastructure | Physical or cloud storage (AWS EBS, HostPath) dynamically created by the StorageClass when a PVC is applied. |

---

## Step 1: Inspect Existing StorageClasses & Deploy PostgreSQL PVC

Before creating PVCs, inspect the existing StorageClasses configured in your Kubernetes cluster.

### 1.1 Inspect Cluster StorageClasses
Run `kubectl get storageclass` (or `kubectl get sc`) to find the default StorageClass marked with `(default)`:

#### Windows (PowerShell) / macOS / Linux (Bash)
```bash
kubectl get storageclass
```
*Example Output (Minikube / EKS):*
```text
NAME                 PROVISIONER                    RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
standard (default)   k8s.io/minikube-hostpath       Delete          Immediate           false                  5d
```

---

### 1.2 PostgreSQL PVC & Deployment Manifest (`manifests/postgres-pvc-deployment.yaml`)

> [!TIP]
> **Automatic Default StorageClass Binding**: Notice that `storageClassName` is omitted from `postgres-pvc`. Kubernetes automatically assigns the cluster default StorageClass (`standard (default)`).

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-pvc
  namespace: default
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  # Omit storageClassName to use cluster default StorageClass
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres-db
  namespace: default
  labels:
    app: postgres
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
        - name: postgres
          image: postgres:15-alpine
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 5432
          env:
            - name: POSTGRES_DB
              value: "ecommerce_db"
            - name: POSTGRES_USER
              value: "postgres"
            - name: POSTGRES_PASSWORD
              value: "PostgresSuperSecret123!"
            - name: PGDATA
              value: "/var/lib/postgresql/data/pgdata"
          volumeMounts:
            - name: postgres-persistent-storage
              mountPath: /var/lib/postgresql/data
      volumes:
        - name: postgres-persistent-storage
          persistentVolumeClaim:
            claimName: postgres-pvc
```

### 1.3 Apply Manifests & Verify Binding

#### Windows (PowerShell) / macOS / Linux (Bash)
```bash
# 1. Apply postgres deployment & PVC
kubectl apply -f manifests/postgres-pvc-deployment.yaml

# 2. Verify PVC status (BOUND to default StorageClass) and PV creation
kubectl get pvc
kubectl get pv

# 3. Verify running PostgreSQL pod
kubectl get pods -l app=postgres
```

---

## Step 2: Insert Data into PostgreSQL Database

Connect to the PostgreSQL pod using `kubectl exec` and populate sample records into `ecommerce_db`:

### Windows (PowerShell)
```powershell
# Get active pod name
$POD_NAME = (kubectl get pods -l app=postgres -o jsonpath='{.items[0].metadata.name}')

# Connect to psql inside container
kubectl exec -it $POD_NAME -- psql -U postgres -d ecommerce_db -c "
CREATE TABLE orders (
    order_id SERIAL PRIMARY KEY,
    customer_name VARCHAR(100),
    amount NUMERIC(10,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
INSERT INTO orders (customer_name, amount) VALUES ('Alice Smith', 250.50);
INSERT INTO orders (customer_name, amount) VALUES ('Bob Jones', 1200.00);
INSERT INTO orders (customer_name, amount) VALUES ('Charlie Brown', 85.25);
"

# Query inserted records
kubectl exec -it $POD_NAME -- psql -U postgres -d ecommerce_db -c "SELECT * FROM orders;"
```

### macOS / Linux (Bash/Zsh)
```bash
# Get active pod name
POD_NAME=$(kubectl get pods -l app=postgres -o jsonpath='{.items[0].metadata.name}')

# Connect to psql inside container and insert data
kubectl exec -it $POD_NAME -- psql -U postgres -d ecommerce_db -c "
CREATE TABLE orders (
    order_id SERIAL PRIMARY KEY,
    customer_name VARCHAR(100),
    amount NUMERIC(10,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
INSERT INTO orders (customer_name, amount) VALUES ('Alice Smith', 250.50);
INSERT INTO orders (customer_name, amount) VALUES ('Bob Jones', 1200.00);
INSERT INTO orders (customer_name, amount) VALUES ('Charlie Brown', 85.25);
"

# Query inserted records
kubectl exec -it $POD_NAME -- psql -U postgres -d ecommerce_db -c "SELECT * FROM orders;"
```

---

## Step 3: Delete PostgreSQL Pod & Verify Data Persistence

Test Kubernetes storage resilience by forcefully terminating the running PostgreSQL pod:

### Windows (PowerShell)
```powershell
# 1. Delete the running PostgreSQL pod
kubectl delete pod -l app=postgres

# 2. Watch Kubernetes Deployment controller recreate a brand new pod automatically
kubectl get pods -l app=postgres -w

# 3. Fetch newly created pod name
$NEW_POD_NAME = (kubectl get pods -l app=postgres -o jsonpath='{.items[0].metadata.name}')

# 4. Connect to new pod and query database to verify data survival!
kubectl exec -it $NEW_POD_NAME -- psql -U postgres -d ecommerce_db -c "SELECT * FROM orders;"
```

### macOS / Linux (Bash/Zsh)
```bash
# 1. Delete the running PostgreSQL pod
kubectl delete pod -l app=postgres

# 2. Watch Kubernetes Deployment controller recreate a brand new pod automatically
kubectl get pods -l app=postgres -w

# 3. Fetch newly created pod name
NEW_POD_NAME=$(kubectl get pods -l app=postgres -o jsonpath='{.items[0].metadata.name}')

# 4. Connect to new pod and query database to verify data survival!
kubectl exec -it $NEW_POD_NAME -- psql -U postgres -d ecommerce_db -c "SELECT * FROM orders;"
```

> [!IMPORTANT]
> **Data Persistence Result**: Notice that all 3 order records (`Alice Smith`, `Bob Jones`, `Charlie Brown`) remain **100% intact** inside the newly created pod because the PVC (`postgres-pvc`) retained the underlying storage volume!

---

## Step 4: Why & How to Use Persistent Volumes with Apache Spark

In Apache Spark on Kubernetes & Amazon EMR on EKS, Persistent Volumes solve critical performance and resilience challenges:

```
+---------------------------------------------------------------------------------------------------+
|                           WHY USE PERSISTENT VOLUMES WITH SPARK?                                  |
+-----------------------------------+-----------------------------------+---------------------------+
| 1. SHUFFLE SPILL STORAGE          | 2. SPARK HISTORY EVENT LOGS       | 3. STREAMING CHECKPOINTS  |
+-----------------------------------+-----------------------------------+---------------------------+
| • Prevents Out-Of-Memory (OOM)    | • Writes JSON event logs to       | • Saves streaming offsets |
|   crashes during large joins/aggs |   shared PVC for post-mortem UI   |   & RDD state across      |
| • Mounts fast local NVMe/SSD PVCs |   analysis via History Server     |   Driver pod restarts     |
|   to spark.local.dir              |                                   |                           |
+-----------------------------------+-----------------------------------+---------------------------+
```

### 4.1 Four Core Use Cases for Spark PVs

1. **Spark Shuffle Spill (`spark.local.dir`)**:
   When Spark shuffle datasets exceed container RAM limits, Spark spills intermediate shuffle files to disk. Mounting a high-throughput NVMe/SSD PVC to `/tmp/spark-local-dir` prevents Executor OOM crashes during multi-terabyte joins.
2. **Spark Event Logging (`spark.eventLog.dir`)**:
   Spark Driver pods write event log files (`.inprogress` and completed logs) to a shared PVC (`spark-history-pvc`). The **Spark History Server** mounts the same PVC to render the web UI after execution finishes.
3. **Structured Streaming Checkpointing (`checkpointLocation`)**:
   PySpark Structured Streaming pipelines require persistent storage to write offset commit metadata and state store checkpoints. Mounting a PVC ensures streaming queries resume seamlessly from exact offset points following driver pod restarts.
4. **Shared Datasets & ML Artifacts**:
   Pre-loading large reference tables, lookup datasets, or ML model weights into a shared PVC allows multiple Spark Executor pods to mount the dataset read-only (`ReadWriteMany` / `ReadOnlyMany`), eliminating repeated S3 network download overhead.

---

## Step 5: Spark PVC Pod Template Manifest (`manifests/spark-pvc-pod-template.yaml`)

Inspect how Spark Driver and Executor pods mount PVCs for shuffle spill and event logs:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: spark-driver-pvc-template
  labels:
    app.kubernetes.io/component: driver
spec:
  containers:
    - name: spark-kubernetes-driver
      env:
        - name: SPARK_LOCAL_DIRS
          value: "/tmp/spark-local-dir"
        - name: SPARK_EVENTLOG_DIR
          value: "file:///tmp/spark-events"
      volumeMounts:
        - name: spark-shuffle-spill-volume
          mountPath: /tmp/spark-local-dir
        - name: spark-eventlog-volume
          mountPath: /tmp/spark-events
  volumes:
    - name: spark-shuffle-spill-volume
      persistentVolumeClaim:
        claimName: spark-shuffle-pvc
    - name: spark-eventlog-volume
      persistentVolumeClaim:
        claimName: spark-history-pvc
```
