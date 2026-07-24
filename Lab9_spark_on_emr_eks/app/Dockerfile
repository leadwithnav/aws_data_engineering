# Start from the official EMR on EKS base runtime image (version 6.10.0)
FROM public.ecr.aws/emr-on-eks/spark/emr-6.10.0:latest

# Switch to root to perform file administration operations
USER root

# Create work-dir structure
RUN mkdir -p /opt/spark/work-dir

# Copy application script and CSV dataset
COPY spark_app.py /opt/spark/work-dir/spark_app.py
COPY sample_data.csv /opt/spark/work-dir/sample_data.csv

# Assign permissions back to the default EMR container user (hadoop)
RUN chown -R hadoop:hadoop /opt/spark/work-dir

# Switch back to the non-root execution user
USER hadoop

# Set workdir
WORKDIR /opt/spark/work-dir
