from pyspark.sql import SparkSession
import pyspark.sql.functions as F

def main():
    # 1. Initialize SparkSession
    spark = SparkSession.builder \
        .appName("SparkLocalDemo") \
        .getOrCreate()

    # 2. Create In-Memory DataFrame
    data = [
        ("Electronics", "Laptop", 1200.50),
        ("Electronics", "Smartphone", 799.99),
        ("Furniture", "Office Chair", 249.99),
        ("Electronics", "Monitor", 349.99),
        ("Furniture", "Standing Desk", 599.00)
    ]
    schema = ["Category", "ProductName", "Amount"]

    df = spark.createDataFrame(data, schema)

    # 3. Filter DataFrame (Amount >= 300.0)
    filtered_df = df.filter(F.col("Amount") >= 300.0)

    # 4. GroupBy & Aggregate
    agg_df = filtered_df.groupBy("Category").agg(
        F.count("ProductName").alias("TotalProducts"),
        F.round(F.sum("Amount"), 2).alias("TotalRevenue")
    )

    # 5. Print output on driver stdout
    print("=== Aggregated Results ===")
    agg_df.show()

    spark.stop()

if __name__ == "__main__":
    main()
