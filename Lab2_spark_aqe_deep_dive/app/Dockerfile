FROM apache/spark:3.5.1

USER root

# Copy application files and sample datasets
COPY spark_engine_demo.py /opt/spark/work-dir/spark_engine_demo.py
COPY sample_orders.csv /opt/spark/work-dir/sample_orders.csv
COPY sample_customers.csv /opt/spark/work-dir/sample_customers.csv

# Ensure correct permissions for the default Spark user (uid 185)
RUN chown -R 185:185 /opt/spark/work-dir

# Expose Spark UI port
EXPOSE 4040

USER 185

ENTRYPOINT [ "/opt/entrypoint.sh" ]
