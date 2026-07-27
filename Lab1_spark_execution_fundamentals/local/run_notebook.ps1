# run_notebook.ps1
# Script to build and run the Spark Execution Fundamentals lab inside Jupyter Notebook, exposing both Jupyter (8888) and Spark UI (4040).

$ErrorActionPreference = "Stop"

# Get the directory of this script to ensure relative paths work
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$AppDir = Join-Path $ScriptDir "../app"

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Pulling Base Image (apache/spark:3.5.1)..." -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
docker pull apache/spark:3.5.1

Write-Host "`n==================================================" -ForegroundColor Cyan
Write-Host "Building Spark Jupyter Notebook Image..." -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Context path: $AppDir" -ForegroundColor Gray

docker build -t spark-jupyter-demo:latest -f (Join-Path $AppDir "Dockerfile.jupyter") $AppDir

if ($LASTEXITCODE -ne 0) {
    Write-Error "Docker build failed!"
    exit $LASTEXITCODE
}

Write-Host "`n==================================================" -ForegroundColor Cyan
Write-Host "Running Spark Jupyter Container..." -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Jupyter Notebook Server: http://localhost:8888" -ForegroundColor Yellow
Write-Host "👉 Direct Notebook URL: http://localhost:8888/notebooks/spark_execution_fundamentals.ipynb" -ForegroundColor Green
Write-Host "`nSpark UI (accessible once SparkSession cell executes):" -ForegroundColor Yellow
Write-Host "👉 http://localhost:4040" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Cyan

# Run the container exposing both Jupyter (8888) and Spark UI (4040)
docker run --rm -it -p 8888:8888 -p 4040:4040 spark-jupyter-demo:latest
