# run_notebook.ps1
# Script to pull and run technoavengers/spark-jupyter-demo image directly

$ErrorActionPreference = "Continue"

# Get the directory of this script to ensure relative paths work
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$AppDir = Join-Path $ScriptDir "../app"
$ImageName = "technoavengers/spark-jupyter-demo:latest"

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Pulling Spark Jupyter Image ($ImageName)..." -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

docker pull $ImageName

if ($LASTEXITCODE -ne 0) {
    Write-Host "Warning: Could not pull remote image from Docker Hub. Attempting local build..." -ForegroundColor Yellow
    docker build -t $ImageName -f (Join-Path $AppDir "Dockerfile.jupyter") $AppDir
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
docker run --rm -it -p 8888:8888 -p 4040:4040 $ImageName
