#!/bin/bash
# run_notebook.sh
# Script to pull and run technoavengers/spark-jupyter-demo image directly

set -e

# Get the directory of this script to ensure relative paths work
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
APP_DIR="$SCRIPT_DIR/../app"
IMAGE_NAME="technoavengers/spark-jupyter-demo:latest"

echo "=================================================="
echo "Pulling Spark Jupyter Image ($IMAGE_NAME)..."
echo "=================================================="

if ! docker pull "$IMAGE_NAME"; then
    echo "Warning: Could not pull remote image from Docker Hub. Attempting local build..."
    docker build -t "$IMAGE_NAME" -f "$APP_DIR/Dockerfile.jupyter" "$APP_DIR"
fi

echo -e "\n=================================================="
echo "Running Spark Jupyter Container..."
echo "=================================================="
echo "Jupyter Notebook Server: http://localhost:8888"
echo "👉 Direct Notebook URL: http://localhost:8888/notebooks/spark_execution_fundamentals.ipynb"
echo -e "\nSpark UI (accessible once SparkSession cell executes):"
echo "👉 http://localhost:4040"
echo "=================================================="

# Run the container exposing both Jupyter (8888) and Spark UI (4040)
docker run --rm -it -p 8888:8888 -p 4040:4040 "$IMAGE_NAME"
