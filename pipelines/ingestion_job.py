from pyspark.sql import SparkSession
from pyspark.sql.functions import col, lit, current_timestamp
from pyspark.sql.types import StructType, StructField, StringType, IntegerType, DoubleType
import os

def get_spark_session():
    return SparkSession.builder.appName("BaseballDataIngestion").getOrCreate()

def get_schema(table_name):
    """Returns the expected schema for each table to ensure strict data quality."""
    schemas = {
        "Batting": StructType([
            StructField("playerID", StringType(), False),
            StructField("yearID", IntegerType(), False),
            StructField("stint", IntegerType(), True),
            StructField("teamID", StringType(), False),
            StructField("lgID", StringType(), True),
            StructField("G", IntegerType(), True),
            StructField("AB", IntegerType(), True),
            StructField("R", IntegerType(), True),
            StructField("H", IntegerType(), True),
            StructField("2B", IntegerType(), True),
            StructField("3B", IntegerType(), True),
            StructField("HR", IntegerType(), True),
            StructField("RBI", IntegerType(), True),
            StructField("SB", IntegerType(), True),
            StructField("CS", IntegerType(), True),
            StructField("BB", IntegerType(), True),
            StructField("SO", IntegerType(), True),
            StructField("IBB", IntegerType(), True),
            StructField("HBP", IntegerType(), True),
            StructField("SH", IntegerType(), True),
            StructField("SF", IntegerType(), True),
            StructField("GIDP", IntegerType(), True)
        ]),
        "People": StructType([
            StructField("playerID", StringType(), False),
            StructField("birthYear", IntegerType(), True),
            StructField("birthMonth", IntegerType(), True),
            StructField("birthDay", IntegerType(), True),
            StructField("birthCountry", StringType(), True),
            StructField("birthState", StringType(), True),
            StructField("birthCity", StringType(), True),
            StructField("deathYear", IntegerType(), True),
            StructField("deathMonth", IntegerType(), True),
            StructField("deathDay", IntegerType(), True),
            StructField("deathCountry", StringType(), True),
            StructField("deathState", StringType(), True),
            StructField("deathCity", StringType(), True),
            StructField("nameFirst", StringType(), True),
            StructField("nameLast", StringType(), True),
            StructField("nameGiven", StringType(), True),
            StructField("weight", IntegerType(), True),
            StructField("height", IntegerType(), True),
            StructField("bats", StringType(), True),
            StructField("throws", StringType(), True),
            StructField("debut", StringType(), True),
            StructField("finalGame", StringType(), True),
            StructField("retroID", StringType(), True),
            StructField("bbrefID", StringType(), True)
        ]),
        "Salaries": StructType([
            StructField("yearID", IntegerType(), False),
            StructField("teamID", StringType(), False),
            StructField("lgID", StringType(), True),
            StructField("playerID", StringType(), False),
            StructField("salary", DoubleType(), True)
        ]),
        "Schools": StructType([
            StructField("schoolID", StringType(), False),
            StructField("name_full", StringType(), True),
            StructField("city", StringType(), True),
            StructField("state", StringType(), True),
            StructField("country", StringType(), True)
        ]),
        "CollegePlaying": StructType([
            StructField("playerID", StringType(), False),
            StructField("schoolID", StringType(), False),
            StructField("yearID", IntegerType(), False)
        ])
    }
    return schemas.get(table_name)

def run_ingestion():
    spark = get_spark_session()
    
    source_base = "s3://baseball-data-platform-landing-dev/"
    target_base = "s3://baseball-data-platform-curated-dev/"
    # source_base = "pipelines/assessment_inputs/" # Local testing only
    # target_base = "curated_data/"
    
    tables = ["Batting", "People", "Salaries", "Schools", "CollegePlaying"]
    
    for table in tables:
        print(f"Processing table: {table}")
        source_path = os.path.join(source_base, f"{table}.csv")
        target_path = os.path.join(target_base, table)
        
        schema = get_schema(table)
        
        # 1. Ingest with strict schema
        df = spark.read.format("csv") \
            .option("header", "true") \
            .schema(schema) \
            .load(source_path)
        
        # 2. Data Quality Checks
        # Drop rows with null keys
        primary_keys = {
            "Batting": ["playerID", "yearID", "teamID"],
            "People": ["playerID"],
            "Salaries": ["playerID", "yearID", "teamID"],
            "Schools": ["schoolID"],
            "CollegePlaying": ["playerID", "schoolID", "yearID"]
        }
        
        keys = primary_keys[table]
        for key in keys:
            df = df.filter(col(key).isNotNull())
            
        # Year range validation
        if "yearID" in df.columns:
            df = df.filter((col("yearID") >= 1800) & (col("yearID") <= 2025))
            
        # 3. Add metadata
        df = df.withColumn("ingested_at", current_timestamp()) \
               .withColumn("source_file", lit(f"{table}.csv"))
        
        # 4. Write to Delta (Idempotent)
        # Partitioning by yearID for Batting as requested
        write_builder = df.write.format("delta").mode("overwrite")
        
        if table == "Batting":
            write_builder = write_builder.partitionBy("yearID")
            
        # Note: In a real environment, we would use .saveAsTable(f"curated.{table}")
        # Here we simulate with file path
        print(f"Writing {table} to {target_path}...")
        write_builder.save(target_path)
        print(f"Successfully processed {table}")

if __name__ == "__main__":
    run_ingestion()
