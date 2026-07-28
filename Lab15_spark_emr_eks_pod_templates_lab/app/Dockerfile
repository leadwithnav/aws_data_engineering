# Base image: Official EMR on EKS Spark runtime
FROM public.ecr.aws/emr-on-eks/spark/emr-6.10.0:latest

USER root

# Create directory structure for application script and pod templates
RUN mkdir -p /opt/spark/work-dir /opt/spark/pod-templates

# Copy PySpark application script
COPY spark_app.py /opt/spark/work-dir/spark_app.py

# Copy Pod Template manifests into container image
COPY ../pod-templates/driver-pod-template.yaml /opt/spark/pod-templates/driver-pod-template.yaml
COPY ../pod-templates/executor-pod-template.yaml /opt/spark/pod-templates/executor-pod-template.yaml

# Grant permissions to default EMR runtime user (hadoop: UID 1000)
RUN chown -R hadoop:hadoop /opt/spark/work-dir /opt/spark/pod-templates

USER hadoop

WORKDIR /opt/spark/work-dir
