import sys
import os
import time
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, count, avg, spark_partition_id

def main():
    print("=" * 70)
    print("🚀 Starting Spark Application on EMR on EKS with Pod Templates")
    print("=" * 70)

    # Initialize Spark Session
    spark = SparkSession.builder \
        .appName("EMR_EKS_PodTemplate_Config_Lab") \
        .getOrCreate()

    sc = spark.sparkContext
    sc.setLogLevel("INFO")

    # 1. Print Environment Variables set by Pod Templates
    print("\n--- 📌 Environment Variables injected via Pod Templates ---")
    print(f"ENVIRONMENT      : {os.environ.get('ENVIRONMENT', 'Not Set')}")
    print(f"LOG_LEVEL        : {os.environ.get('LOG_LEVEL', 'Not Set')}")
    print(f"SPARK_JAVA_OPT   : {os.environ.get('SPARK_JAVA_OPT_G1GC', 'Not Set')}")

    # 2. Inspect Active Spark Configurations
    print("\n--- ⚙️ Active Spark Configuration Parameters ---")
    relevant_configs = [
        "spark.master",
        "spark.app.name",
        "spark.driver.memory",
        "spark.executor.memory",
        "spark.executor.instances",
        "spark.kubernetes.driver.podTemplateFile",
        "spark.kubernetes.executor.podTemplateFile",
        "spark.sql.adaptive.enabled",
        "spark.sql.adaptive.coalescePartitions.enabled",
        "spark.dynamicAllocation.enabled",
        "spark.kubernetes.container.image"
    ]

    for key in relevant_configs:
        val = spark.conf.get(key, "Not Configured")
        print(f"  {key:<45} : {val}")

    # 3. Create Sample Dataset and Perform Data Processing
    print("\n--- 📊 Processing Sample Analytics Workload ---")
    data = [
        ("user_101", "click", "us-west-2", 45.5, "2026-07-28"),
        ("user_102", "purchase", "us-east-1", 120.0, "2026-07-28"),
        ("user_103", "click", "eu-central-1", 15.2, "2026-07-28"),
        ("user_104", "purchase", "us-west-2", 350.0, "2026-07-28"),
        ("user_105", "view", "us-west-2", 5.0, "2026-07-28"),
        ("user_106", "purchase", "ap-southeast-1", 89.9, "2026-07-28"),
        ("user_107", "click", "us-east-1", 22.1, "2026-07-28"),
        ("user_108", "purchase", "eu-central-1", 210.0, "2026-07-28")
    ] * 500  # Scale dataset up

    columns = ["user_id", "event_type", "aws_region", "amount", "event_date"]
    df = spark.createDataFrame(data, schema=columns)

    print(f"Total Record Count: {df.count()}")
    
    # Aggregation query
    print("\n--- 📈 Regional Sales Aggregations ---")
    agg_df = df.filter(col("event_type") == "purchase") \
               .groupBy("aws_region") \
               .agg(
                   count("user_id").alias("total_purchases"),
                   avg("amount").alias("avg_spend_usd")
               ) \
               .orderBy(col("total_purchases").desc())

    agg_df.show()

    # 4. Verify Partition Distribution across Executors
    print("\n--- 🧩 Partition & Execution Metadata ---")
    df_part = df.withColumn("partition_id", spark_partition_id())
    partition_counts = df_part.groupBy("partition_id").count()
    partition_counts.show()

    print("\n✅ Spark Application Completed Successfully!")
    print("=" * 70)

    spark.stop()

if __name__ == "__main__":
    main()
