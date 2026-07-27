# run_local.ps1
# Script to build and test the Spark in-memory application container locally on Windows.

$ErrorActionPreference = "Stop"

# Get the directory of this script to ensure relative paths work
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$AppDir = Join-Path $ScriptDir "../app"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Building Docker Image Locally..." -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "App directory context: $AppDir" -ForegroundColor Gray

# Run docker build with app/ as context
docker build -t spark-on-minikube:latest -f (Join-Path $AppDir "Dockerfile") $AppDir

if ($LASTEXITCODE -ne 0) {
    Write-Error "Docker build failed!"
    exit $LASTEXITCODE
}

Write-Host "`n==========================================" -ForegroundColor Cyan
Write-Host "Running Spark In-Memory Application Locally..." -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# Run spark-submit inside the container (in-memory DataFrame creation & transformations)
docker run --rm -it spark-on-minikube:latest /opt/spark/bin/spark-submit /opt/spark/work-dir/spark_app.py

if ($LASTEXITCODE -ne 0) {
    Write-Warning "`nSpark execution completed with a non-zero exit code."
} else {
    Write-Host "`nSpark execution completed successfully!" -ForegroundColor Green
}
