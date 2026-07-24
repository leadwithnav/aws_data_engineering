#!/bin/bash
# submit_spark_minikube.sh
# Script to download Spark client binaries and submit the Spark application to local Minikube from macOS.

set -e

# Parse arguments
S3_BUCKET=""
AWS_REGION="us-east-1"

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -b|--bucket) S3_BUCKET="$2"; shift ;;
        -r|--region) AWS_REGION="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

# Setup directories
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BASE_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"
K8S_DIR="$BASE_DIR/k8s"
SPARK_VERSION="spark-3.5.1-bin-hadoop3"
SPARK_HOME="$BASE_DIR/$SPARK_VERSION"
IMAGE_URI="spark-on-minikube:latest"

echo "================================================"
echo "Spark on Minikube Job Submitter (macOS)"
echo "================================================"
echo "Spark Home Path: $SPARK_HOME"
echo "Target Image   : $IMAGE_URI"
echo "================================================"

# 1. Verify Prerequisites
echo -e "\n[1/5] Verifying local prerequisites..."

# Check Java
if ! command -v java &> /dev/null; then
    echo "ERROR: Java (JRE/JDK) is not installed or not in PATH. Please install Java (e.g., brew install openjdk@17) and configure JAVA_HOME." >&2
    exit 1
fi
echo "Java is installed: $(java -version 2>&1 | head -n 1)"

# Check kubectl
if ! command -v kubectl &> /dev/null; then
    echo "ERROR: kubectl is not installed. Please install it first." >&2
    exit 1
fi
echo "kubectl is installed."

# Check Minikube Status
echo "Checking if Minikube is running..."
MINIKUBE_STATUS=$(minikube status --format "{{.Host}}" 2>/dev/null || true)
if [ "$MINIKUBE_STATUS" != "Running" ]; then
    echo "ERROR: Minikube is not running. Please start it by running 'minikube start --driver=docker --memory=4096 --cpus=3' first." >&2
    exit 1
fi
echo "Minikube is running."

# 2. Set up Spark Client Binaries on macOS if missing
echo -e "\n[2/5] Checking for Spark client binaries..."
if [ ! -d "$SPARK_HOME" ]; then
    echo "Spark client binaries not found. Downloading $SPARK_VERSION..."
    TAR_FILE="$BASE_DIR/$SPARK_VERSION.tgz"
    
    # Download Spark
    curl -L -o "$TAR_FILE" "https://archive.apache.org/dist/spark/spark-3.5.1/$SPARK_VERSION.tgz"
    
    echo "Extracting Spark binaries..."
    # Extract
    tar -xzf "$TAR_FILE" -C "$BASE_DIR"
    
    # Remove archive
    rm "$TAR_FILE"
    echo "Spark binaries set up successfully at $SPARK_HOME"
else
    echo "Spark client binaries already present."
fi

# 3. Configure Kubernetes Context and Apply RBAC
echo -e "\n[3/5] Setting up Kubernetes context and permissions..."

# Switch context to minikube
kubectl config use-context minikube

# Load Docker image into Minikube
echo "Loading '$IMAGE_URI' image into Minikube..."
minikube image load "$IMAGE_URI"

# Apply RBAC configuration
echo "Applying Spark Kubernetes RBAC..."
kubectl apply -f "$K8S_DIR/spark-rbac.yaml"

# Get Kubernetes Master Endpoint
K8S_MASTER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
echo "K8s Master API Endpoint: $K8S_MASTER"

# 4. Prepare Spark Submit Arguments
echo -e "\n[4/5] Preparing job submission..."

SUBMIT_CMD="$SPARK_HOME/bin/spark-submit"

# Build arguments array
ARGS=(
    "--master" "k8s://$K8S_MASTER"
    "--deploy-mode" "cluster"
    "--name" "spark-on-minikube-job"
    "--conf" "spark.kubernetes.container.image=$IMAGE_URI"
    "--conf" "spark.kubernetes.authenticate.driver.serviceAccountName=spark"
    "--conf" "spark.executor.instances=2"
    "--conf" "spark.kubernetes.driver.pod.name=spark-driver"
)

if [ -n "$S3_BUCKET" ]; then
    echo "Configuring job for S3 integration targeting bucket: $S3_BUCKET"
    
    # Retrieve credentials from local AWS configuration
    ACCESS_KEY=$(aws configure get aws_access_key_id 2>/dev/null || true)
    SECRET_KEY=$(aws configure get aws_secret_access_key 2>/dev/null || true)
    
    if [ -z "$ACCESS_KEY" ] || [ -z "$SECRET_KEY" ]; then
        echo "ERROR: AWS credentials not found. Run 'aws configure' to set them up before running S3 jobs on Minikube." >&2
        exit 1
    fi
    
    ARGS+=(
        "--conf" "spark.hadoop.fs.s3a.impl=org.apache.hadoop.fs.s3a.S3AFileSystem"
        "--conf" "spark.hadoop.fs.s3a.access.key=$ACCESS_KEY"
        "--conf" "spark.hadoop.fs.s3a.secret.key=$SECRET_KEY"
        "local:///opt/spark/work-dir/spark_app.py"
        "s3a://$S3_BUCKET/sample_data.csv"
        "s3a://$S3_BUCKET/spark-output"
    )
else
    echo "Running job using embedded container CSV data..."
    ARGS+=(
        "local:///opt/spark/work-dir/spark_app.py"
        "local:///opt/spark/work-dir/sample_data.csv"
    )
fi

# 5. Submit Spark Job
echo -e "\n[5/5] Submitting Spark job to Minikube..."
echo "Executing: $SUBMIT_CMD ${ARGS[*]}"

# Remove existing driver pod if it exists
kubectl delete pod spark-driver --ignore-not-found=true

# Submit job
"$SUBMIT_CMD" "${ARGS[@]}"

echo -e "\nJob submission completed successfully!"
echo "You can monitor execution using:"
echo "  kubectl get pods -w"
echo "  kubectl logs spark-driver"
