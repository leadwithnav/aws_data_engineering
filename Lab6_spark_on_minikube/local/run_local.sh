#!/bin/bash
# run_local.sh
# Script to build and test the Spark application container locally on macOS.

set -e

# Get the directory of this script to ensure relative paths work
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
APP_DIR="$SCRIPT_DIR/../app"

echo "=========================================="
echo "Building Docker Image Locally..."
echo "=========================================="
echo "App directory context: $APP_DIR"

# Run docker build with app/ as context
docker build -t spark-on-minikube:latest -f "$APP_DIR/Dockerfile" "$APP_DIR"

echo -e "\n=========================================="
echo "Running Spark Application Locally..."
echo "=========================================="

# Run the spark-submit inside the container, passing the copied local CSV file as the input path argument
docker run --rm -it spark-on-minikube:latest /opt/spark/bin/spark-submit /opt/spark/work-dir/spark_app.py /opt/spark/work-dir/sample_data.csv

echo -e "\nSpark execution completed successfully!"
