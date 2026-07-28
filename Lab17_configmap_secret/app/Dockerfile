FROM public.ecr.aws/emr-on-eks/spark/emr-6.10.0:latest

USER root

# Create working directory and pod templates directory
RUN mkdir -p /opt/spark/work-dir /opt/spark/pod-templates

# Copy PySpark application script
COPY spark_s3_to_snowflake.py /opt/spark/work-dir/spark_s3_to_snowflake.py

# Copy Driver and Executor Pod Templates
COPY ../pod-templates/driver-pod-template.yaml /opt/spark/pod-templates/driver-pod-template.yaml
COPY ../pod-templates/executor-pod-template.yaml /opt/spark/pod-templates/executor-pod-template.yaml

# Assign permissions to default EMR user (hadoop: UID 1000)
RUN chown -R hadoop:hadoop /opt/spark/work-dir /opt/spark/pod-templates

USER hadoop

WORKDIR /opt/spark/work-dir
