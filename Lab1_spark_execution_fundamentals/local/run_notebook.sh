#!/bin/bash
# run_notebook.sh
# Script to build and run the Spark Execution Fundamentals lab inside Jupyter Notebook, exposing both Jupyter (8888) and Spark UI (4040).

set -e

# Get the directory of this script to ensure relative paths work
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
APP_DIR="$SCRIPT_DIR/../app"

echo "=================================================="
echo "Pulling Base Image (apache/spark:3.5.1)..."
echo "=================================================="
docker pull apache/spark:3.5.1

echo -e "\n=================================================="
echo "Building Spark Jupyter Notebook Image..."
echo "=================================================="
echo "Context path: $APP_DIR"

docker build -t spark-jupyter-demo:latest -f "$APP_DIR/Dockerfile.jupyter" "$APP_DIR"

echo -e "\n=================================================="
echo "Running Spark Jupyter Container..."
echo "=================================================="
echo "Jupyter Notebook Server: http://localhost:8888"
echo "👉 Direct Notebook URL: http://localhost:8888/notebooks/spark_execution_fundamentals.ipynb"
echo -e "\nSpark UI (accessible once SparkSession cell executes):"
echo "👉 http://localhost:4040"
echo "=================================================="

# Run the container exposing both Jupyter (8888) and Spark UI (4040)
docker run --rm -it -p 8888:8888 -p 4040:4040 spark-jupyter-demo:latest
