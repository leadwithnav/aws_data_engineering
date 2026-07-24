FROM apache/spark:3.5.1

USER root

# Install curl (if not present) to download the S3 connector JARs
RUN apt-get update && \
    apt-get install -y curl && \
    rm -rf /var/lib/apt/lists/*

# Download AWS S3 connector jars (hadoop-aws and aws-java-sdk-bundle)
# Match Hadoop version 3.3.4 (bundled in Spark 3.5.1)
RUN curl -sS -o /opt/spark/jars/hadoop-aws-3.3.4.jar https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.3.4/hadoop-aws-3.3.4.jar && \
    curl -sS -o /opt/spark/jars/aws-java-sdk-bundle-1.12.262.jar https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/1.12.262/aws-java-sdk-bundle-1.12.262.jar

# Copy our PySpark app script and sample CSV data to /opt/spark/work-dir/
COPY spark_app.py /opt/spark/work-dir/spark_app.py
COPY sample_data.csv /opt/spark/work-dir/sample_data.csv

# Set proper permissions for the Spark user (uid 185)
RUN chown -R 185:185 /opt/spark/work-dir

# Switch back to the default Spark non-root user
USER 185

# Use the default Spark image entrypoint
ENTRYPOINT [ "/opt/entrypoint.sh" ]
