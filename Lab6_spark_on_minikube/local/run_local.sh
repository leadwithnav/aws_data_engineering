#!/bin/bash
# run_local.sh
# Script to build and test the Spark in-memory application container locally on macOS/Linux.

set -e

# Get the directory of this script to ensure relative paths work
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
APP_DIR="$SCRIPT_DIR/../app"

# Detect Apple Silicon (M1/M2/M3/M4) architecture on macOS
PLATFORM_FLAG=""
if [[ "$(uname -s)" == "Darwin" && "$(uname -m)" == "arm64" ]]; then
    echo "ℹ️ Apple Silicon detected (arm64). Enforcing --platform linux/amd64..."
    PLATFORM_FLAG="--platform linux/amd64"
fi

echo "=========================================="
echo "Building Docker Image Locally..."
echo "=========================================="
echo "App directory context: $APP_DIR"

# Run docker build with app/ as context
docker build $PLATFORM_FLAG -t spark-on-minikube:latest -f "$APP_DIR/Dockerfile" "$APP_DIR"

echo -e "\n=========================================="
echo "Running Spark In-Memory Application Locally..."
echo "=========================================="

# Run spark-submit inside the container (in-memory DataFrame creation & transformations)
docker run $PLATFORM_FLAG --rm -it spark-on-minikube:latest /opt/spark/bin/spark-submit /opt/spark/work-dir/spark_app.py

echo -e "\nSpark execution completed successfully!"
