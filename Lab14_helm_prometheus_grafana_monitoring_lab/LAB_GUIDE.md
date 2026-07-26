# Lab 14: Observability & Monitoring — Helm, Prometheus, Grafana, Flask & Spark

## Executive Summary
This lab covers deploying **kube-prometheus-stack** using **Helm** in the `monitoring` namespace on Minikube, building and running an instrumented **Python Flask app** in a separate `apps` namespace, enabling cross-namespace Prometheus scraping, and building custom **Grafana Dashboards**.

---

## Observability Architecture (Cross-Namespace Scraping)

```
[ Namespace: apps ]                              [ Namespace: monitoring ]
+----------------------------+                   +----------------------------------+
| Flask App Deployment       |                   | Prometheus Server                |
| (flask-prometheus-app:v1)  |                   | (kube-prometheus-stack)          |
| Service: flask-service:5000| <--- (Scrapes) ---| Config: serviceMonitorNS={all}   |
| ServiceMonitor: apps       |                   |                                  |
+----------------------------+                   | Grafana UI (Port 3000)           |
                                                 +----------------------------------+
```

---

## Hands-On Commands Workflow

```bash
# 1. Install Helm & Add Chart Repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# 2. Deploy Prometheus & Grafana in 'monitoring' Namespace
kubectl create namespace monitoring

helm install prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set grafana.adminPassword=admin123 \
  --set prometheus.prometheusSpec.serviceMonitorNamespaceSelector={} \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false

# 3. Build Flask App Image directly in Minikube
minikube image build -t flask-prometheus-app:v1 .

# 4. Create 'apps' Namespace & Deploy Flask App
kubectl create namespace apps

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: flask-app
  namespace: apps
  labels:
    app: flask-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: flask-app
  template:
    metadata:
      labels:
        app: flask-app
    spec:
      containers:
      - name: flask-container
        image: flask-prometheus-app:v1
        imagePullPolicy: Never
        ports:
        - containerPort: 5000
          name: http
---
apiVersion: v1
kind: Service
metadata:
  name: flask-service
  namespace: apps
  labels:
    app: flask-app
spec:
  ports:
  - port: 5000
    targetPort: 5000
    name: http
  selector:
    app: flask-app
EOF

# 5. Apply ServiceMonitor in 'apps' Namespace for Cross-Namespace Scraping
cat <<EOF | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: flask-app-monitor
  namespace: apps
  labels:
    release: prometheus-stack
spec:
  selector:
    matchLabels:
      app: flask-app
  endpoints:
  - port: http
    path: /metrics
    interval: 15s
EOF

# 6. Access Grafana UI at http://localhost:3000
kubectl port-forward svc/prometheus-stack-grafana 3000:80 -n monitoring
```
