# Lab Guide: Spark on EKS via Amazon EMR — Airflow Orchestration & Pod Templates

This comprehensive hands-on guide walks you through orchestrating PySpark workloads on **Amazon EMR on EKS** using **Apache Airflow** (running locally via **Docker Compose**) with custom **Spark Configuration Parameters** and Kubernetes **Driver & Executor Pod Templates**.

> [!IMPORTANT]
> **CLI AWS Credential Security**: In enterprise setups, AWS Access Keys and Secret Keys should **NEVER** be stored in `.env` files or committed to code repositories. This lab demonstrates 3 secure CLI methods to pass AWS credentials dynamically to Airflow without writing secrets to `.env`.

---

## Architectural Workflow

```mermaid
graph TD
    subgraph Local CLI & Host Environment
        CLI[AWS CLI / Host Environment Variables] -->|Mount ~/.aws or Shell Env| DOCKER[Docker Compose]
    end

    subgraph Airflow Stack (Docker Compose)
        DOCKER --> WEB[Airflow Webserver:8080]
        DOCKER --> SCHED[Airflow Scheduler]
        DAG[emr_eks_spark_dag.py] --> SCHED
    end

    subgraph AWS Cloud Infrastructure
        SCHED -->|EmrContainerOperator via aws_default| EMR_API[AWS EMR Containers API]
        S3[S3 Bucket: pod-templates/*.yaml] --> EMR_API
        ECR[Amazon ECR Repository] -->|Pull Custom Spark Image| EKS[EKS Cluster / EMR Virtual Cluster]
        EMR_API -->|Orchestrates Spark Pods| EKS
        EKS --> DRIVER[Spark Driver Pod]
        EKS --> EXEC[Spark Executor Pods]
    end
```

---

## Step 1: Supply AWS Credentials via CLI & Launch Local Airflow

Choose one of the 3 secure CLI options below to pass AWS credentials to Airflow without editing or saving secrets inside `.env`.

### Option A: Host AWS CLI Credentials Mount (Recommended)
If you have already configured the AWS CLI on your machine using `aws configure`, Airflow automatically reads credentials from your host `~/.aws/credentials` file via Docker volume mount (`~/.aws:/home/airflow/.aws:ro`).

```bash
# 1. Verify host AWS CLI credentials
aws sts get-caller-identity

# 2. Start Airflow containers directly (Airflow automatically mounts ~/.aws)
docker compose up -d --build
```

---

### Option B: Export Shell Environment Variables on CLI before launching Docker

Pass credentials dynamically in your terminal session. Docker Compose passes these environment variables into the Airflow containers without writing them to disk.

#### Windows (PowerShell)
```powershell
$env:AWS_ACCESS_KEY_ID = "YOUR_AWS_ACCESS_KEY_ID"
$env:AWS_SECRET_ACCESS_KEY = "YOUR_AWS_SECRET_ACCESS_KEY"
$env:AWS_SESSION_TOKEN = "YOUR_AWS_SESSION_TOKEN" # Optional (if using temporary credentials/SSO)
$env:AWS_DEFAULT_REGION = "us-west-2"

# Start local Airflow stack
docker compose up -d --build
```

#### macOS / Linux / CloudShell (Bash/Zsh)
```bash
export AWS_ACCESS_KEY_ID="YOUR_AWS_ACCESS_KEY_ID"
export AWS_SECRET_ACCESS_KEY="YOUR_AWS_SECRET_ACCESS_KEY"
export AWS_SESSION_TOKEN="YOUR_AWS_SESSION_TOKEN" # Optional (if using temporary credentials/SSO)
export AWS_DEFAULT_REGION="us-west-2"

# Start local Airflow stack
docker compose up -d --build
```

---

### Option C: Set Airflow AWS Connection (`aws_default`) via Airflow CLI

Start Airflow and create/update the `aws_default` connection dynamically using `airflow connections add` inside the running container.

#### Windows (PowerShell)
```powershell
# 1. Start Airflow containers
docker compose up -d --build

# 2. Add AWS connection via Airflow CLI
docker compose exec airflow-webserver airflow connections add 'aws_default' `
  --conn-type 'aws' `
  --conn-login 'YOUR_AWS_ACCESS_KEY_ID' `
  --conn-password 'YOUR_AWS_SECRET_ACCESS_KEY' `
  --conn-extra '{"region_name": "us-west-2"}'
```

#### macOS / Linux (Bash/Zsh)
```bash
# 1. Start Airflow containers
docker compose up -d --build

# 2. Add AWS connection via Airflow CLI
docker compose exec airflow-webserver airflow connections add 'aws_default' \
  --conn-type 'aws' \
  --conn-login 'YOUR_AWS_ACCESS_KEY_ID' \
  --conn-password 'YOUR_AWS_SECRET_ACCESS_KEY' \
  --conn-extra '{"region_name": "us-west-2"}'
```

---

## Step 2: Access Airflow Web UI & Verify AWS Connection

1. Open your browser and navigate to: **[http://localhost:8080](http://localhost:8080)**
2. Log in with default credentials:
   - **Username**: `admin`
   - **Password**: `admin`
3. Verify Airflow AWS Connection (`aws_default`):
   - Navigate to **Admin -> Connections**.
   - Confirm `aws_default` is configured and active.

---

## Step 3: Pod Templates & Airflow DAG Authoring

### 3.1 Driver & Executor Pod Templates
Ensure your Pod template YAML files exist in `pod-templates/`:
- `pod-templates/driver-pod-template.yaml` (custom labels, prometheus annotations, `emptyDir` scratch volume, driver nodeSelector)
- `pod-templates/executor-pod-template.yaml` (G1GC options, executor nodeSelector, memory/CPU limits)

### 3.2 Upload Pod Templates to S3

#### Windows (PowerShell)
```powershell
aws s3 cp pod-templates/driver-pod-template.yaml "s3://$env:S3_BUCKET/pod-templates/driver-pod-template.yaml"
aws s3 cp pod-templates/executor-pod-template.yaml "s3://$env:S3_BUCKET/pod-templates/executor-pod-template.yaml"
```

#### macOS / Linux (Bash/Zsh)
```bash
aws s3 cp pod-templates/driver-pod-template.yaml s3://${S3_BUCKET}/pod-templates/driver-pod-template.yaml
aws s3 cp pod-templates/executor-pod-template.yaml s3://${S3_BUCKET}/pod-templates/executor-pod-template.yaml
```

### 3.3 Build & Push EMR Spark Image to ECR

```bash
cd app
docker build --platform linux/amd64 -t spark-emr-pod-templates:latest .

# Authenticate & Push to ECR
aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin 123456789012.dkr.ecr.us-west-2.amazonaws.com
docker tag spark-emr-pod-templates:latest 123456789012.dkr.ecr.us-west-2.amazonaws.com/spark-emr-eks:v1
docker push 123456789012.dkr.ecr.us-west-2.amazonaws.com/spark-emr-eks:v1
```

---

## Step 4: Airflow DAG Code (`dags/emr_eks_spark_dag.py`)

Inspect how `EmrContainerOperator` passes pod templates and Spark configurations:

```python
from datetime import datetime, timedelta
from airflow import DAG
from airflow.providers.amazon.aws.operators.emr import EmrContainerOperator

default_args = {
    "owner": "data_engineering_team",
    "start_date": datetime(2026, 7, 28),
    "retries": 1,
}

with DAG(
    dag_id="emr_eks_spark_pod_templates_dag",
    default_args=default_args,
    schedule_interval=None,
    catchup=False,
) as dag:

    submit_emr_eks_spark_job = EmrContainerOperator(
        task_id="submit_spark_job_to_emr_eks",
        name="airflow-emr-eks-spark-pod-templates-job",
        virtual_cluster_id="abc123def456ghi789",
        execution_role_arn="arn:aws:iam::123456789012:role/EMRJobExecutionRole",
        release_label="emr-6.10.0-latest",
        job_driver={
            "sparkSubmitJobDriver": {
                "entryPoint": "local:///opt/spark/work-dir/spark_app.py",
                "sparkSubmitParameters": (
                    "--conf spark.kubernetes.container.image=123456789012.dkr.ecr.us-west-2.amazonaws.com/spark-emr-eks:v1 "
                    "--conf spark.kubernetes.driver.podTemplateFile=s3://my-emr-eks-pod-templates-bucket/pod-templates/driver-pod-template.yaml "
                    "--conf spark.kubernetes.executor.podTemplateFile=s3://my-emr-eks-pod-templates-bucket/pod-templates/executor-pod-template.yaml "
                    "--conf spark.driver.memory=1024m "
                    "--conf spark.executor.memory=1024m "
                    "--conf spark.executor.instances=2 "
                    "--conf spark.sql.adaptive.enabled=true"
                ),
            }
        },
        aws_conn_id="aws_default",
        wait_for_completion=True,
    )
```

---

## Step 5: Trigger DAG & Monitor Execution

### 5.1 Trigger DAG from Airflow UI
1. Go to Airflow DAGs list at `http://localhost:8080`.
2. Toggle the DAG switch from **Off** to **On** for `emr_eks_spark_pod_templates_dag`.
3. Click the **Play (Trigger DAG)** button.

### 5.2 Trigger DAG via Airflow CLI inside Docker
```bash
docker compose exec airflow-scheduler airflow dags trigger emr_eks_spark_pod_templates_dag
```

---

## Step 6: Verify EKS Driver/Executor Pods & Stream Logs

Connect `kubectl` to your EKS cluster and inspect the running Spark pods:

```bash
# Connect kubectl to EKS
aws eks update-kubeconfig --name spark-eks-cluster --region us-west-2

# List running Spark pods
kubectl get pods -n spark-emr -l app.kubernetes.io/name=spark-job

# Inspect applied merged Pod spec on driver pod
kubectl get pod -n spark-emr -l app.kubernetes.io/component=driver -o yaml

# Stream logs from driver pod
kubectl logs -n spark-emr -l app.kubernetes.io/component=driver -f
```

---

## Step 7: Clean Up Local Airflow Stack

When finished, shut down your local Airflow containers:

```bash
docker compose down -v
```
