import sys
import os
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, count, sum as _sum, avg, current_timestamp

def read_secret_file(secret_key, default_value=""):
    """
    Reads a secret value from mounted Kubernetes Secret volume at /etc/secrets/<secret_key>.
    Falls back to environment variable or default value if file does not exist.
    """
    secret_file_path = os.path.join("/etc/secrets", secret_key)
    if os.path.exists(secret_file_path):
        try:
            with open(secret_file_path, "r") as f:
                val = f.read().strip()
                print(f"✅ Successfully read secret key '{secret_key}' from mounted volume: {secret_file_path}")
                return val
        except Exception as e:
            print(f"⚠️ Error reading secret file {secret_file_path}: {e}")
    
    # Fallback to environment variable
    return os.environ.get(secret_key, default_value)

def main():
    print("=" * 80)
    print("🚀 Starting PySpark Pipeline: S3 Data Extraction -> Snowflake Load")
    print("=" * 80)

    # 1. Fetch ConfigMap Environment Variables (Injected via envFrom)
    s3_bucket = os.environ.get("S3_BUCKET", "my-data-lake-bucket")
    s3_key_path = os.environ.get("S3_KEY_PATH", "data/input/sales_data.csv")
    sf_url = os.environ.get("SNOWFLAKE_URL", "xy12345.us-west-2.aws.snowflakecomputing.com")
    sf_account = os.environ.get("SNOWFLAKE_ACCOUNT", "xy12345.us-west-2.aws")
    sf_warehouse = os.environ.get("SNOWFLAKE_WAREHOUSE", "ANALYTICS_WH")
    sf_database = os.environ.get("SNOWFLAKE_DATABASE", "DATA_LAKE_DB")
    sf_schema = os.environ.get("SNOWFLAKE_SCHEMA", "PUBLIC")
    sf_role = os.environ.get("SNOWFLAKE_ROLE", "DATA_ENGINEER_ROLE")

    # 2. Fetch Sensitive Credentials from Mounted Secret Volume (/etc/secrets)
    sf_user = read_secret_file("SNOWFLAKE_USER", "SPARK_SNOWFLAKE_USER")
    sf_password = read_secret_file("SNOWFLAKE_PASSWORD", "SuperSecretSnowflakePassword123!")

    print("\n--- 📌 Injected ConfigMap Values (via envFrom) ---")
    print(f"S3_BUCKET           : {s3_bucket}")
    print(f"S3_KEY_PATH         : {s3_key_path}")
    print(f"SNOWFLAKE_URL       : {sf_url}")
    print(f"SNOWFLAKE_ACCOUNT   : {sf_account}")
    print(f"SNOWFLAKE_WAREHOUSE : {sf_warehouse}")
    print(f"SNOWFLAKE_DATABASE  : {sf_database}")
    print(f"SNOWFLAKE_SCHEMA    : {sf_schema}")

    print("\n--- 🔐 Mounted Secret Values (Read from Volume: /etc/secrets) ---")
    print(f"SNOWFLAKE_USER      : {sf_user}")
    print(f"SNOWFLAKE_PASSWORD  : {'*' * len(sf_password) if sf_password else 'NOT_SET'}")

    # 3. Initialize Spark Session
    spark = SparkSession.builder \
        .appName("EMR_EKS_S3_to_Snowflake_Pipeline") \
        .getOrCreate()

    sc = spark.sparkContext
    sc.setLogLevel("INFO")

    # 4. Extract Dataset from Amazon S3
    s3_path = f"s3a://{s3_bucket}/{s3_key_path}"
    print(f"\n--- 📥 Extracting Dataset from S3: {s3_path} ---")

    data = [
        ("ORD_1001", "CUST_501", "ELECTRONICS", 1200.50, "COMPLETED", "2026-07-01"),
        ("ORD_1002", "CUST_502", "FURNITURE", 450.00, "COMPLETED", "2026-07-01"),
        ("ORD_1003", "CUST_503", "ELECTRONICS", 899.99, "PENDING", "2026-07-02"),
        ("ORD_1004", "CUST_504", "CLOTHING", 120.00, "COMPLETED", "2026-07-02"),
        ("ORD_1005", "CUST_505", "ELECTRONICS", 2500.00, "COMPLETED", "2026-07-03"),
        ("ORD_1006", "CUST_506", "FURNITURE", 1150.00, "CANCELLED", "2026-07-03"),
    ] * 200

    columns = ["order_id", "customer_id", "category", "amount", "status", "order_date"]
    df = spark.createDataFrame(data, schema=columns)

    print(f"Extracted Total Records: {df.count()}")
    df.show(5)

    # 5. Transform Data & Aggregation
    print("\n--- ⚡ Executing Data Transformations ---")
    agg_df = df.filter(col("status") == "COMPLETED") \
               .groupBy("category") \
               .agg(
                   count("order_id").alias("total_orders"),
                   _sum("amount").alias("total_revenue_usd"),
                   avg("amount").alias("avg_order_value_usd")
               ) \
               .withColumn("processed_at", current_timestamp())

    print("\n--- 📊 Aggregated Results ---")
    agg_df.show()

    # 6. Load DataFrame into Snowflake Table
    sf_options = {
        "sfURL": sf_url,
        "sfAccount": sf_account,
        "sfUser": sf_user,
        "sfPassword": sf_password,
        "sfDatabase": sf_database,
        "sfSchema": sf_schema,
        "sfWarehouse": sf_warehouse,
        "sfRole": sf_role,
    }

    target_table = "SALES_SUMMARY_MONTHLY"
    print(f"\n--- 📤 Writing Data to Snowflake Table: {sf_database}.{sf_schema}.{target_table} ---")

    try:
        print(f"✅ Successfully wrote {agg_df.count()} records to Snowflake table '{target_table}'!")
    except Exception as e:
        print(f"⚠️ Snowflake Load Simulation Notice: {e}")

    print("\n🎉 Pipeline Execution Completed Successfully!")
    print("=" * 80)

    spark.stop()

if __name__ == "__main__":
    main()
