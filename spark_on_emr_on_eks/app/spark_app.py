import sys
from pyspark.sql import SparkSession
import pyspark.sql.functions as F

def main():
    print("==========================================")
    print("Starting Spark EMR on EKS Application...")
    print("==========================================")
    
    # Check for required input path argument
    if len(sys.argv) < 2:
        print("Error: Missing input path argument.")
        print("Usage: spark_app.py <input_csv_path> [output_parquet_path]")
        sys.exit(1)
        
    input_path = sys.argv[1]
    output_path = sys.argv[2] if len(sys.argv) > 2 else None
    
    print(f"Input CSV Path: {input_path}")
    if output_path:
        print(f"Output Parquet Path: {output_path}")
    else:
        print("Output Path not provided. Aggregation results will be displayed on console only.")
        
    # Initialize SparkSession
    spark = SparkSession.builder \
        .appName("SparkOnEMRonEKS-Demo") \
        .getOrCreate()
        
    spark.sparkContext.setLogLevel("INFO")
    
    print(f"Reading CSV file from: {input_path} ...")
    # Read the CSV (S3 path or local path)
    df = spark.read \
        .option("header", "true") \
        .option("inferSchema", "true") \
        .csv(input_path)
        
    print("Preview of read CSV data:")
    df.show(10, truncate=False)
    
    print("Performing aggregations: calculating metrics per ProductID...")
    # Aggregate data: calculate total sales amount, total quantity, and average transaction amount per ProductID
    aggregated_df = df.groupBy("ProductID") \
        .agg(
            F.round(F.sum("Amount"), 2).alias("TotalSalesAmount"),
            F.sum("Quantity").alias("TotalQuantitySold"),
            F.round(F.avg("Amount"), 2).alias("AverageTransactionAmount")
        ) \
        .orderBy("ProductID")
        
    print("Aggregation results:")
    aggregated_df.show(20, truncate=False)
    
    if output_path:
        print(f"Writing aggregated results to: {output_path} ...")
        # Save as parquet format
        aggregated_df.write \
            .mode("overwrite") \
            .parquet(output_path)
        print("Write completed successfully!")
        
    print("==========================================")
    print("Spark EMR on EKS Application Finished.")
    print("==========================================")
    spark.stop()

if __name__ == "__main__":
    main()
