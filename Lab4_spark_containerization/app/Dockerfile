FROM apache/spark:3.5.1

USER root

# Copy our PySpark app script and sample CSV data to /opt/spark/work-dir/
COPY spark_app.py /opt/spark/work-dir/spark_app.py
COPY sample_data.csv /opt/spark/work-dir/sample_data.csv

# Set proper permissions for the Spark user (uid 185)
RUN chown -R 185:185 /opt/spark/work-dir

# Switch back to the default Spark non-root user
USER 185

# Use the default Spark image entrypoint
ENTRYPOINT [ "/opt/entrypoint.sh" ]
