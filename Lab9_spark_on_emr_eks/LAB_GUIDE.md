# Lab Guide: Running Spark Workloads via Amazon EMR on EKS

This step-by-step guide walks you through deploying containerized PySpark applications using **Amazon EMR on EKS**.

> [!WARNING]
> **Platform Team Provisioning vs. Data Engineer Role**: In enterprise production environments, the **EMR Virtual Cluster** and **IAM Execution Role** are created and managed by the **Platform / Cloud Infrastructure Team**. As a **Data Engineer**, you will receive these pre-created details (Cluster ID, Execution Role ARN, and ECR Repository URL) to submit your Spark applications to EKS via EMR on EKS.

---

## Architectural Workflow

```mermaid
graph TD
    subgraph Platform Provisioning (Platform Team)
        P1[Create IAM Execution Role] --> P2[Create EMR Virtual Cluster]
    end
    subgraph Provided Credentials (Data Engineer Task)
        A[EMR Virtual Cluster ID] --> D[aws emr-containers start-job-run]
        B[ECR Repository URL] --> C[docker build & push]
        C -->|Pushes spark-emr-eks:latest| ECR[Amazon ECR]
        ECR --> D
        ROLE[IAM Execution Role ARN] --> D
    end
    subgraph Amazon EMR on EKS
        D -->|Orchestrates Spark Pods| E[EKS Driver & Executor Pods]
    end
```

---

## Step 1: Platform Provisioning (Reference Step)

> [!NOTE]
> *This step is performed by the Platform Team during initial setup.*

### 1.1 Create Kubernetes Namespace `spark-emr`
```bash
kubectl create namespace spark-emr
```

### 1.2 Create IAM Execution Role (`EMRJobExecutionRole`)

#### Windows (PowerShell)
```powershell
$TrustPolicy = '{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Service": "emr-containers.amazonaws.com" },
      "Action": "sts:AssumeRole"
    }
  ]
}'

aws iam create-role --role-name EMRJobExecutionRole --assume-role-policy-document $TrustPolicy
aws iam attach-role-policy --role-name EMRJobExecutionRole --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess
```

#### macOS / Linux (Bash/Zsh)
```bash
aws iam create-role --role-name EMRJobExecutionRole --assume-role-policy-document '{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Service": "emr-containers.amazonaws.com" },
    "Action": "sts:AssumeRole"
  }]
}'
aws iam attach-role-policy --role-name EMRJobExecutionRole --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess
```

### 1.3 Create EMR Virtual Cluster on EKS

#### Windows (PowerShell)
```powershell
aws emr-containers create-virtual-cluster `
  --name "spark-emr-vc" `
  --container-provider "{
    `"id`": `"spark-eks-cluster`",
    `"type`": `"EKS`",
    `"info`": {
      `"eksInfo`": { `"namespace`": `"spark-emr`" }
    }
  }"
```

#### macOS / Linux (Bash/Zsh)
```bash
aws emr-containers create-virtual-cluster \
  --name "spark-emr-vc" \
  --container-provider '{
    "id": "spark-eks-cluster",
    "type": "EKS",
    "info": {
      "eksInfo": { "namespace": "spark-emr" }
    }
  }'
```

### 1.4 Check Execution Role & Retrieve ARN

Verify that the IAM Execution Role exists and retrieve its ARN:

#### Windows (PowerShell)
```powershell
$EXECUTION_ROLE_ARN = (aws iam get-role --role-name EMRJobExecutionRole --query "Role.Arn" --output text)
Write-Host "Execution Role ARN: $EXECUTION_ROLE_ARN"
```

#### macOS / Linux / AWS CloudShell (Bash/Zsh)
```bash
EXECUTION_ROLE_ARN=$(aws iam get-role --role-name EMRJobExecutionRole --query "Role.Arn" --output text)
echo "Execution Role ARN: $EXECUTION_ROLE_ARN"
```

---

## Step 2: Configure Environment Variables & Connect to EKS

Set your provided lab environment variables:

### Windows (PowerShell)
```powershell
$env:AWS_REGION = "us-west-2"
# Replace with your provided Virtual Cluster ID
$env:VIRTUAL_CLUSTER_ID = "abc123def456ghi789"

# Replace with your provided ECR Repository URL
$env:ECR_REPO_URL = "786461327180.dkr.ecr.us-west-2.amazonaws.com/spark-emr-eks"

# Replace with your provided EMR Execution Role ARN
$env:EXECUTION_ROLE_ARN = "arn:aws:iam::786461327180:role/EMRJobExecutionRole"

# Connect kubectl to EKS cluster
aws eks update-kubeconfig --name spark-eks-cluster --region $env:AWS_REGION
```

### macOS / Linux / AWS CloudShell (Bash/Zsh)
```bash
export AWS_REGION="us-west-2"
# Replace with your provided Virtual Cluster ID
export VIRTUAL_CLUSTER_ID="abc123def456ghi789"

# Replace with your provided ECR Repository URL
export ECR_REPO_URL="786461327180.dkr.ecr.us-west-2.amazonaws.com/spark-emr-eks"

# Replace with your provided EMR Execution Role ARN
export EXECUTION_ROLE_ARN="arn:aws:iam::786461327180:role/EMRJobExecutionRole"

# Connect kubectl to EKS cluster
aws eks update-kubeconfig --name spark-eks-cluster --region $AWS_REGION
```

---

## Step 3: Build & Push Custom EMR Container Image

### 3.1 Explore Dockerfile (`app/Dockerfile`)
```dockerfile
# Start from the official EMR on EKS base runtime image (version 6.10.0)
FROM public.ecr.aws/emr-on-eks/spark/emr-6.10.0:latest

# Switch to root to perform file administration
USER root

RUN mkdir -p /opt/spark/work-dir

COPY spark_app.py /opt/spark/work-dir/spark_app.py
COPY sample_data.csv /opt/spark/work-dir/sample_data.csv

# Assign permissions to default EMR user (hadoop: UID 1000)
RUN chown -R hadoop:hadoop /opt/spark/work-dir

# Switch to non-root execution user
USER hadoop

WORKDIR /opt/spark/work-dir
```

### 3.2 Compile Docker Image
```bash
cd d:\trainings\aws_data_engineering\Lab9_spark_on_emr_eks\app
docker build --platform linux/amd64 -t spark-emr-eks:latest .
```

### 3.3 Authenticate & Push to ECR Repo URL

#### Windows (PowerShell)
```powershell
$RegistryUrl = $env:ECR_REPO_URL.Split("/")[0]
aws ecr get-login-password --region $env:AWS_REGION | docker login --username AWS --password-stdin $RegistryUrl
docker tag spark-emr-eks:latest "$env:ECR_REPO_URL:latest"
docker push "$env:ECR_REPO_URL:latest"
```

#### macOS / Linux (Bash/Zsh)
```bash
RegistryUrl=$(echo $ECR_REPO_URL | cut -d'/' -f1)
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $RegistryUrl
docker tag spark-emr-eks:latest "$ECR_REPO_URL:latest"
docker push "$ECR_REPO_URL:latest"
```

---

## Step 4: Submit Spark Job Run via EMR CLI

### Windows (PowerShell)
```powershell
aws emr-containers start-job-run `
  --virtual-cluster-id $env:VIRTUAL_CLUSTER_ID `
  --name "spark-emr-eks-job" `
  --execution-role-arn $env:EXECUTION_ROLE_ARN `
  --release-label "emr-6.10.0-latest" `
  --job-driver "{
    `"sparkSubmitJobDriver`": {
      `"entryPoint`": `"local:///opt/spark/work-dir/spark_app.py`",
      `"sparkSubmitParameters`": `"--conf spark.kubernetes.container.image=$env:ECR_REPO_URL:latest --conf spark.executor.instances=1 --conf spark.driver.memory=512m --conf spark.executor.memory=512m`"
    }
  }"
```

### macOS / Linux / AWS CloudShell (Bash/Zsh)
```bash
aws emr-containers start-job-run \
  --virtual-cluster-id $VIRTUAL_CLUSTER_ID \
  --name "spark-emr-eks-job" \
  --execution-role-arn $EXECUTION_ROLE_ARN \
  --release-label "emr-6.10.0-latest" \
  --job-driver '{
    "sparkSubmitJobDriver": {
      "entryPoint": "local:///opt/spark/work-dir/spark_app.py",
      "sparkSubmitParameters": "--conf spark.kubernetes.container.image='"$ECR_REPO_URL"':latest --conf spark.executor.instances=1 --conf spark.driver.memory=512m --conf spark.executor.memory=512m"
    }
  }'
```

---

## Step 5: Monitor Job Execution & Stream Pod Logs

### 5.1 Check Job Status via CLI
```powershell
$env:JOB_ID = "<YOUR_JOB_ID_FROM_ABOVE_OUTPUT>"
aws emr-containers describe-job-run --virtual-cluster-id $env:VIRTUAL_CLUSTER_ID --id $env:JOB_ID
```

### 5.2 View EKS Pods & Stream Logs
```bash
# View active pods in the EMR Virtual Cluster namespace
kubectl get pods -A

# Stream logs from driver pod once running
kubectl logs -n <EMR_NAMESPACE> <DRIVER_POD_NAME> -f
```
