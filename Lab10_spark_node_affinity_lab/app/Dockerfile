FROM apache/spark:3.5.1

USER root

# Set working directory
WORKDIR /opt/spark/work-dir

# Copy PySpark in-memory application script
COPY spark_app.py /opt/spark/work-dir/spark_app.py

# Set proper permissions for default Spark non-root user (uid 185)
RUN chown -R 185:185 /opt/spark/work-dir

# Switch to default Spark user
USER 185

# Use default Spark image entrypoint
ENTRYPOINT [ "/opt/entrypoint.sh" ]
