# macOS Environment Setup Guide

This guide provides step-by-step instructions to set up your local development environment for AWS Data Engineering, Kubernetes (EKS/Minikube), and containerized applications on macOS.

---

## 🛠️ Prerequisites: Homebrew
On macOS, we use **Homebrew** as our primary package manager. If you do not have Homebrew installed, open your Terminal and run:
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```
Follow the post-installation prompts in your terminal to add Homebrew to your system `PATH` (typically by running a couple of `echo` and `eval` commands shown in the terminal output).

---

## 📖 Manual Step-by-Step Installation

Follow the instructions below for each component.

### 1. Git
Git is required for version control and cloning repositories.
* **CLI (Homebrew)**
  ```bash
  brew install git
  ```
* **Verify installation**: `git --version`

---

### 2. AWS CLI (v2)
The Amazon Web Services Command Line Interface is used to interact with AWS services, including EKS.
* **CLI (Homebrew)**
  ```bash
  brew install awscli
  ```
* **Verify installation**: `aws --version`

---

### 3. Visual Studio Code
A lightweight but powerful source code editor.
* **CLI (Homebrew)**
  ```bash
  brew install --cask visual-studio-code
  ```
* **Verify installation**: `code --version`

---

### 4. Docker Desktop
Provides a local container runtime engine, required for Minikube and container development.
* **CLI (Homebrew)**
  ```bash
  brew install --cask docker
  ```
* **Manual Setup**:
  1. Open the **Docker** application from your Applications folder.
  2. Follow the setup wizard to complete the configuration.
  3. Ensure that Docker is running (you should see the green status icon in the menu bar).
  
> [!IMPORTANT]
> **Apple Silicon (M1/M2/M3/M4) vs. Intel**:
> Docker Desktop automatically detects and runs natively on both Apple Silicon and Intel chips. On Apple Silicon, Docker leverages macOS's virtualization framework natively. Ensure Rosetta 2 is installed if prompted, although native arm64 containers will run automatically.

---

### 5. Kubernetes CLI (`kubectl`)
`kubectl` is the primary command-line tool for controlling Kubernetes clusters (both local Minikube and remote EKS).
* **CLI (Homebrew)**
  ```bash
  brew install kubectl
  ```
* **Verify installation**: `kubectl version --client`

---

### 6. `eksctl`
`eksctl` is a simple CLI tool for creating and managing clusters on Amazon EKS.
* **CLI (Homebrew)**
  ```bash
  brew tap eksctl-io/tap
  brew install eksctl-io/tap/eksctl
  ```
* **Verify installation**: `eksctl version`

---

### 7. Minikube
Minikube runs a local, single-node Kubernetes cluster on your Mac for testing and learning.
* **CLI (Homebrew)**
  ```bash
  brew install minikube
  ```
* **Verify installation**: `minikube version`

---

### 8. Java Development Kit (JDK 17)
Required on your local machine to run the local `spark-submit` command-line utility when launching jobs onto Kubernetes.
* **CLI (Homebrew)**:
  ```bash
  brew install openjdk@17
  ```
* **Configuration (Crucial for macOS)**:
  1. Create a symlink so that the system Java wrapper can discover this JDK version:
     ```bash
     sudo ln -sfn /opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk-17.jdk
     ```
  2. Add the environment variables to your shell configuration file (typically `~/.zshrc` on modern macOS):
     ```bash
     echo 'export JAVA_HOME=$(/usr/libexec/java_home -v 17)' >> ~/.zshrc
     echo 'export PATH="$JAVA_HOME/bin:$PATH"' >> ~/.zshrc
     source ~/.zshrc
     ```
  3. Verify installation:
     ```bash
     java -version
     ```
     *(Verify it prints `openjdk version "17.0.x"`).*

> [!WARNING]
> **Java Version Warning**:
> Apache Spark 3.5.x is incompatible with Java versions newer than JDK 17 (such as JDK 21 or higher). Using a newer version will cause `UnsupportedOperationException` errors during `spark-submit`. Ensure that JDK 17 is configured as your active Java version.

---

### 9. Apache Spark Client (v3.5.1)
Apache Spark client binaries are required on your macOS machine to submit jobs to remote EKS or local Minikube clusters using `spark-submit`.

1. Download the archive manually:
   ```bash
   curl -O https://archive.apache.org/dist/spark/spark-3.5.1/spark-3.5.1-bin-hadoop3.tgz
   ```
2. Extract the archive and move it to a stable directory (e.g., `~/spark`):
   ```bash
   mkdir -p ~/spark
   tar -xzf spark-3.5.1-bin-hadoop3.tgz -C ~/spark
   rm spark-3.5.1-bin-hadoop3.tgz
   ```
3. Add the Spark environment variables and `bin` folder to your path in `~/.zshrc`:
   ```bash
   echo 'export SPARK_HOME=$HOME/spark/spark-3.5.1-bin-hadoop3' >> ~/.zshrc
   echo 'export PATH="$SPARK_HOME/bin:$PATH"' >> ~/.zshrc
   source ~/.zshrc
   ```

---

### 10. Python 3 (v3.10+)
Required on macOS to execute PySpark driver processes during local `spark-submit`.

* **CLI (Homebrew)**
  ```bash
  brew install python@3.10
  ```
* **Verify installation**: 
  Make sure `python3` points to Python 3.10+ (you can verify with `python3 --version`). 
  You can alias `python` to `python3` in your `~/.zshrc`:
  ```bash
  echo 'alias python=python3' >> ~/.zshrc
  source ~/.zshrc
  ```

---

## 🔍 Verification Checklist

Open a **new** terminal window and run the following commands to verify everything is set up and in your `PATH`:

| Command | Expected Output | Status |
| :--- | :--- | :---: |
| `git --version` | `git version 2.x.x...` | ⬜ |
| `aws --version` | `aws-cli/2.x.x...` | ⬜ |
| `code --version` | `1.x.x` | ⬜ |
| `docker --version` | `Docker version 2x.x.x...` | ⬜ |
| `java -version` | `openjdk version "17.0.x"...` | ⬜ |
| `python3 --version` | `Python 3.x.x` | ⬜ |
| `spark-submit --version` | `Welcome to Spark version 3.5.1` | ⬜ |
| `kubectl version --client` | `Client Version: v1.x.x...` | ⬜ |
| `eksctl version` | `0.x.x` | ⬜ |
| `minikube version` | `minikube version: v1.x.x...` | ⬜ |

---

## 🚀 Post-Installation Steps

### Configure AWS Credentials
To use `aws` and `eksctl`, you must configure your credentials. Run the following and enter your access key, secret key, region, and format:
```bash
aws configure
```

### Clean up Legacy PySpark Environment Variables (Important)
If you have previously configured shell-wide `PYSPARK_PYTHON` or `PYSPARK_DRIVER_PYTHON` environment variables, they will automatically propagate to your Kubernetes/EKS clusters and crash remote executor/driver pods.

You can handle this in two ways:

* **Option A: Clear temporarily for the current session (Recommended/Safe)**:
  Clear them in the current terminal session before submitting jobs to Kubernetes:
  ```bash
  unset PYSPARK_PYTHON
  unset PYSPARK_DRIVER_PYTHON
  ```

* **Option B: Clean up permanently (Recommended if not running Spark locally outside containers)**:
  Remove any export statements for `PYSPARK_PYTHON` or `PYSPARK_DRIVER_PYTHON` from your `~/.zshrc` or `~/.bash_profile` files, then reload the terminal.

---

### Start Minikube (Local Testing)
To start a local Kubernetes cluster using Docker as the driver:
```bash
minikube start --driver=docker
```
Verify that Minikube is active:
```bash
kubectl get nodes
```
