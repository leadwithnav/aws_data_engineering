# submit_spark_minikube.ps1
# Script to download Spark client binaries and submit the Spark application to local Minikube from Windows.

[CmdletBinding()]
param (
    [string]$S3Bucket, # Optional: For S3 integration testing
    [string]$AwsRegion = "us-east-1"
)

$ErrorActionPreference = "Stop"

# Setup directories
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$BaseDir = Join-Path $ScriptDir ".."
$K8sDir = Join-Path $BaseDir "k8s"
$SparkVersion = "spark-3.5.1-bin-hadoop3"
$SparkHome = Join-Path $BaseDir $SparkVersion
$ImageUri = "spark-on-minikube:latest"

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Spark on Minikube Job Submitter (Windows)" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Spark Home Path: $SparkHome" -ForegroundColor Gray
Write-Host "Target Image   : $ImageUri" -ForegroundColor Gray
Write-Host "================================================" -ForegroundColor Cyan

# 1. Verify Prerequisites
Write-Host "`n[1/5] Verifying local prerequisites..." -ForegroundColor Cyan

# Check Java
try {
    $javaVer = java -version 2>&1
    Write-Host "Java is installed." -ForegroundColor Green
} catch {
    Write-Error "Java (JRE/JDK) is not installed or not in PATH. Please install Java (e.g., winget install Microsoft.OpenJDK.17) to run spark-submit locally."
    exit 1
}

# Check kubectl
if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
    Write-Error "kubectl is not installed. Please install it first."
    exit 1
}

# Check Minikube Status
Write-Host "Checking if Minikube is running..." -ForegroundColor Yellow
$MinikubeStatus = minikube status --format "{{.Host}}" 2>$null
if ($MinikubeStatus -ne "Running") {
    Write-Error "Minikube is not running. Please start it by running 'minikube start --driver=docker --memory=4096 --cpus=3' first."
    exit 1
}
Write-Host "Minikube is running." -ForegroundColor Green

# 2. Set up Spark Client Binaries on Windows if missing
Write-Host "`n[2/5] Checking for Spark client binaries..." -ForegroundColor Cyan
if (-not (Test-Path $SparkHome)) {
    Write-Host "Spark client binaries not found. Downloading $SparkVersion..." -ForegroundColor Yellow
    $TarFile = Join-Path $BaseDir "$SparkVersion.tgz"
    
    # Download Spark
    Invoke-WebRequest -Uri "https://archive.apache.org/dist/spark/spark-3.5.1/$SparkVersion.tgz" -OutFile $TarFile
    
    Write-Host "Extracting Spark binaries..." -ForegroundColor Yellow
    # Extract
    tar -xzf $TarFile -C $BaseDir
    
    # Remove archive
    Remove-Item $TarFile -Force
    Write-Host "Spark binaries set up successfully at $SparkHome" -ForegroundColor Green
} else {
    Write-Host "Spark client binaries already present." -ForegroundColor Green
}

# 3. Configure Kubernetes Context and Apply RBAC
Write-Host "`n[3/5] Setting up Kubernetes context and permissions..." -ForegroundColor Cyan

# Switch context to minikube
kubectl config use-context minikube

# Load Docker image into Minikube
Write-Host "Loading '$ImageUri' image into Minikube..." -ForegroundColor Yellow
minikube image load $ImageUri
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to load image. Ensure you built the image using 'local/run_local.ps1' or 'docker build -t spark-on-minikube:latest app/' first."
    exit 1
}

# Apply RBAC configuration
Write-Host "Applying Spark Kubernetes RBAC..." -ForegroundColor Yellow
kubectl apply -f (Join-Path $K8sDir "spark-rbac.yaml")

# Get Kubernetes Master Endpoint
$K8sMaster = kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}'
Write-Host "K8s Master API Endpoint: $K8sMaster" -ForegroundColor Green

# 4. Prepare Spark Submit Arguments
Write-Host "`n[4/5] Preparing job submission..." -ForegroundColor Cyan

$SubmitCmd = Join-Path $SparkHome "bin/spark-submit.cmd"

$Args = @(
    "--master", "k8s://$K8sMaster",
    "--deploy-mode", "cluster",
    "--name", "spark-on-minikube-job",
    "--conf", "spark.kubernetes.container.image=$ImageUri",
    "--conf", "spark.kubernetes.authenticate.driver.serviceAccountName=spark",
    "--conf", "spark.executor.instances=2",
    "--conf", "spark.kubernetes.driver.pod.name=spark-driver"
)

if ($S3Bucket) {
    Write-Host "Configuring job for S3 integration targeting bucket: $S3Bucket" -ForegroundColor Yellow
    
    # Retrieve credentials from local AWS configuration for Minikube S3 access
    $AccessKey = aws configure get aws_access_key_id
    $SecretKey = aws configure get aws_secret_access_key
    
    if (-not $AccessKey -or -not $SecretKey) {
        Write-Error "AWS credentials not found. Run 'aws configure' to set them up before running S3 jobs on Minikube."
        exit 1
    }
    
    $Args += "--conf", "spark.hadoop.fs.s3a.impl=org.apache.hadoop.fs.s3a.S3AFileSystem"
    $Args += "--conf", "spark.hadoop.fs.s3a.access.key=$AccessKey"
    $Args += "--conf", "spark.hadoop.fs.s3a.secret.key=$SecretKey"
    
    $Args += "local:///opt/spark/work-dir/spark_app.py"
    $Args += "s3a://$S3Bucket/sample_data.csv"
    $Args += "s3a://$S3Bucket/spark-output"
} else {
    Write-Host "Running job using embedded container CSV data..." -ForegroundColor Yellow
    $Args += "local:///opt/spark/work-dir/spark_app.py"
    $Args += "local:///opt/spark/work-dir/sample_data.csv"
}

# 5. Submit Spark Job
Write-Host "`n[5/5] Submitting Spark job to Minikube..." -ForegroundColor Cyan
Write-Host "Executing: $SubmitCmd $Args" -ForegroundColor DarkGray

# Remove existing driver pod if it exists
kubectl delete pod spark-driver --ignore-not-found=true > $null

# Submit
& $SubmitCmd $Args

if ($LASTEXITCODE -eq 0) {
    Write-Host "`nJob submission completed successfully!" -ForegroundColor Green
    Write-Host "You can monitor execution using:" -ForegroundColor Yellow
    Write-Host "  kubectl get pods -w" -ForegroundColor Yellow
    Write-Host "  kubectl logs spark-driver" -ForegroundColor Yellow
} else {
    Write-Error "Job submission failed."
}
