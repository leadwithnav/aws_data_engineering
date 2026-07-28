# Lab Guide: ConfigMap envFrom Injection & Secret Volume Mapping in PySpark S3-to-Snowflake Pipeline

This step-by-step guide walks you through injecting Kubernetes **ConfigMaps via `envFrom`**, mapping **Secrets via Volume Mounts (`/etc/secrets`)**, reading secret files directly inside **PySpark** code, offline container image loading in **Minikube** (`docker pull` -> `minikube image load`), and orchestrating an **Amazon EMR on EKS** PySpark S3-to-Snowflake pipeline using **Apache Airflow**.

---

## Architectural Workflow

```mermaid
graph TD
    subgraph Part 1: Local Minikube & Standard Pod
        DP[docker pull nginx:alpine] --> MIL[minikube image load nginx:alpine]
        CM1[configmap.yaml] -->|Injects via envFrom| POD[demo-configmap-secret-pod]
        CLI_SEC[kubectl create secret generic app-secret] -->|Maps via Volume Mount /etc/secrets| POD
    end

    subgraph Part 2: EMR on EKS & Airflow (S3 to Snowflake)
        AIRFLOW[Airflow EmrContainerOperator] --> EMR_API[AWS EMR Virtual Cluster]
        S3_DATA[Amazon S3 Input Dataset] --> SPARK[EMR Spark Driver / Executor Pods]
        SPARK_CONFIG[Driver & Executor Pod Templates] -->|ConfigMap via envFrom / Secret via Volume| SPARK
        SPARK -->|Reads /etc/secrets/SNOWFLAKE_PASSWORD| SNOWFLAKE[(Snowflake Data Warehouse)]
    end
```

---

## Step 1: Minikube Offline Image Loading Workflow

If your Minikube cluster cannot directly download images from Docker Hub, pull the image locally using Docker CLI and load it directly into Minikube:

### Windows (PowerShell)
```powershell
# 1. Start Minikube cluster
minikube start --cpus 2 --memory 4096

# 2. Pull container image locally via Docker CLI
docker pull nginx:alpine

# 3. Load local container image into Minikube cluster
minikube image load nginx:alpine

# 4. Verify image is present inside Minikube image cache
minikube image ls | Select-String "nginx"
```

### macOS / Linux / CloudShell (Bash/Zsh)
```bash
# 1. Start Minikube cluster
minikube start --cpus 2 --memory 4096

# 2. Pull container image locally via Docker CLI
docker pull nginx:alpine

# 3. Load local container image into Minikube cluster
minikube image load nginx:alpine

# 4. Verify image is present inside Minikube image cache
minikube image ls | grep "nginx"
```

---

## Step 2: Create ConfigMap & Secret (via kubectl CLI)

### 2.1 Create ConfigMap Manifest (`manifests/configmap.yaml`)
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  S3_BUCKET: "my-data-lake-bucket"
  S3_KEY_PATH: "data/input/sales_data.parquet"
  SNOWFLAKE_URL: "xy12345.us-west-2.aws.snowflakecomputing.com"
  SNOWFLAKE_ACCOUNT: "xy12345.us-west-2.aws"
  SNOWFLAKE_WAREHOUSE: "ANALYTICS_WH"
  SNOWFLAKE_DATABASE: "DATA_LAKE_DB"
  SNOWFLAKE_SCHEMA: "PUBLIC"
  SNOWFLAKE_ROLE: "DATA_ENGINEER_ROLE"
```

Apply ConfigMap:
```bash
kubectl apply -f manifests/configmap.yaml
```

### 2.2 Create Secret Directly via `kubectl create secret` (No YAML file)

> [!IMPORTANT]
> **No YAML file for Secrets**: To prevent committing sensitive passwords to code repositories, create the Kubernetes Secret directly on the CLI using `kubectl create secret generic`.

#### Windows (PowerShell)
```powershell
kubectl create secret generic app-secret `
  --from-literal=SNOWFLAKE_USER="SPARK_SNOWFLAKE_USER" `
  --from-literal=SNOWFLAKE_PASSWORD="SuperSecretSnowflakePassword123!" `
  --from-literal=AWS_ACCESS_KEY_ID="AKIAIOSFODNN7EXAMPLE" `
  --from-literal=AWS_SECRET_ACCESS_KEY="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
```

#### macOS / Linux (Bash/Zsh)
```bash
kubectl create secret generic app-secret \
  --from-literal=SNOWFLAKE_USER="SPARK_SNOWFLAKE_USER" \
  --from-literal=SNOWFLAKE_PASSWORD="SuperSecretSnowflakePassword123!" \
  --from-literal=AWS_ACCESS_KEY_ID="AKIAIOSFODNN7EXAMPLE" \
  --from-literal=AWS_SECRET_ACCESS_KEY="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
```

---

## Step 3: Deploy & Verify Pod (ConfigMap via `envFrom` & Secret via Volume Mount)

### 3.1 Standard Pod Manifest (`manifests/pod-with-configmap-secret.yaml`)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: demo-configmap-secret-pod
spec:
  containers:
    - name: demo-container
      image: nginx:alpine
      # 1. ConfigMap injected as Environment Variables via envFrom
      envFrom:
        - configMapRef:
            name: app-config
      # 2. Secret mapped as Volume Mount
      volumeMounts:
        - name: secret-volume
          mountPath: /etc/secrets
          readOnly: true
  volumes:
    - name: secret-volume
      secret:
        secretName: app-secret
```

### 3.2 Apply & Inspect Environment & Secret Files

#### Windows (PowerShell)
```powershell
# Deploy pod
kubectl apply -f manifests/pod-with-configmap-secret.yaml

# Verify pod status
kubectl get pods

# Inspect ConfigMap environment variables (populated via envFrom)
kubectl exec -it demo-configmap-secret-pod -- env | Select-String "SNOWFLAKE|S3"

# Read mounted Secret files directly from volume mount
kubectl exec -it demo-configmap-secret-pod -- cat /etc/secrets/SNOWFLAKE_USER
kubectl exec -it demo-configmap-secret-pod -- cat /etc/secrets/SNOWFLAKE_PASSWORD
```

#### macOS / Linux (Bash/Zsh)
```bash
# Deploy pod
kubectl apply -f manifests/pod-with-configmap-secret.yaml

# Verify pod status
kubectl get pods

# Inspect ConfigMap environment variables (populated via envFrom)
kubectl exec -it demo-configmap-secret-pod -- env | grep -E "SNOWFLAKE|S3"

# Read mounted Secret files directly from volume mount
kubectl exec -it demo-configmap-secret-pod -- cat /etc/secrets/SNOWFLAKE_USER
kubectl exec -it demo-configmap-secret-pod -- cat /etc/secrets/SNOWFLAKE_PASSWORD
```

---

## Step 4: EMR on EKS Driver & Executor Pod Templates

In Amazon EMR on EKS, Pod Templates use `envFrom` for ConfigMap injection and `volumeMounts` for Secret mapping.

### 4.1 Driver Pod Template (`pod-templates/driver-pod-template.yaml`)
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: spark-driver-template
spec:
  containers:
    - name: spark-kubernetes-driver
      envFrom:
        - configMapRef:
            name: app-config
      volumeMounts:
        - name: secret-volume
          mountPath: /etc/secrets
          readOnly: true
  volumes:
    - name: secret-volume
      secret:
        secretName: app-secret
```

---

## Step 5: PySpark S3 to Snowflake Data Pipeline (`app/spark_s3_to_snowflake.py`)

Inspect how PySpark reads ConfigMap variables from environment (`os.environ.get`) and reads sensitive credentials directly from mounted secret files (`/etc/secrets/SNOWFLAKE_PASSWORD`):

```python
import os
from pyspark.sql import SparkSession

def read_secret_file(secret_key):
    secret_path = f"/etc/secrets/{secret_key}"
    if os.path.exists(secret_path):
        with open(secret_path, "r") as f:
            return f.read().strip()
    return os.environ.get(secret_key, "")

# 1. Read ConfigMap variables (injected via envFrom)
s3_bucket = os.environ.get("S3_BUCKET", "my-data-lake-bucket")
sf_url = os.environ.get("SNOWFLAKE_URL")

# 2. Read Secret credentials from Volume Mount (/etc/secrets)
sf_user = read_secret_file("SNOWFLAKE_USER")
sf_password = read_secret_file("SNOWFLAKE_PASSWORD")

spark = SparkSession.builder.appName("EMR_EKS_S3_to_Snowflake").getOrCreate()

# Extract from S3
df = spark.read.parquet(f"s3a://{s3_bucket}/data/input/sales_data.parquet")

# Write to Snowflake using credentials read from /etc/secrets
df.write \
   .format("snowflake") \
   .option("sfURL", sf_url) \
   .option("sfUser", sf_user) \
   .option("sfPassword", sf_password) \
   .option("dbtable", "SALES_SUMMARY_MONTHLY") \
   .mode("overwrite") \
   .save()
```

---

## Step 6: Airflow Orchestration via EMR Virtual Cluster

### 6.1 Start Local Airflow Stack
```bash
docker compose up -d --build
```

### 6.2 Trigger Airflow DAG (`dags/emr_eks_snowflake_dag.py`)
```bash
docker compose exec airflow-scheduler airflow dags trigger emr_eks_s3_to_snowflake_pipeline_dag
```

### 6.3 Verify EKS Pod Execution & Logs
```bash
# Connect kubectl to EKS cluster
aws eks update-kubeconfig --name spark-eks-cluster --region us-west-2

# Stream driver logs
kubectl logs -n spark-emr -l app.kubernetes.io/component=driver -f
```
