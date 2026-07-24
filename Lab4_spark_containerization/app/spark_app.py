import sys
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

def main():
    print("==========================================")
    print("Starting Spark Application Container...")
    print("==========================================")

    # Initialize Spark Session
    spark = SparkSession.builder \
        .appName("SparkContainerizationApp") \
        .getOrCreate()

    # Set log level to ERROR to hide verbose info logs
    spark.sparkContext.setLogLevel("ERROR")

    csv_path = "/opt/spark/work-dir/sample_data.csv"
    print(f"Reading transaction data from {csv_path}...")
    
    try:
        # Read the CSV dataset
        df = spark.read \
            .option("header", "true") \
            .option("inferSchema", "true") \
            .csv(csv_path)

        print("\nInput Schema details:")
        df.printSchema()

        print("\nFirst 5 transactions:")
        df.show(5)

        print("Aggregating sales revenue by category...")
        summary_df = df.groupBy("Category") \
            .agg(
                F.count("OrderID").alias("TotalOrders"),
                F.round(F.sum("Amount"), 2).alias("TotalRevenue")
            ) \
            .orderBy(F.col("TotalRevenue").desc())

        print("\nAggregation Summary Results:")
        summary_df.show()
        print("Aggregation successfully completed!")
        
    except Exception as e:
        print(f"Error executing Spark App: {e}", file=sys.stderr)
        sys.exit(1)
    finally:
        spark.stop()
        print("\nSpark Session stopped successfully.")

if __name__ == "__main__":
    main()
