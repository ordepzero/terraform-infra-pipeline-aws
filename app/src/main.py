from pyspark.sql import SparkSession
from awsglue.context import GlueContext 
from awsglue.transforms import *
from awsglue.dynamicframe import DynamicFrame
from awsglue.utils import getResolvedOptions
from awsglue.job import Job
from pyspark.sql.functions import year, month, dayofmonth 
import sys

class JobELT83:
    def __init__(self, spark, glueContext, input_path, output_path, database_name, table_name):
        self.spark = spark
        self.glueContext = glueContext
        self.input_path = input_path
        self.output_path = output_path
        self.database_name = database_name
        self.table_name = table_name

    def read_parquet_from_s3(self):
        print("Lendo os dados do 53: (self.input_path}")
        try:
            df = self.spark.read.parquet(self.input_path) 
            return df
        except Exception as e:
            print("[read_parquet_from_s3] Erro ao ler parquet: {e}")
            raise

    def write_parquet_to_s3(self, df):
        try:
            df = df.withColumn("ano", year(df["data_pregao"])) \
                    .withColumn("mes", month(df["data_pregao"]))\
                    .withColumn("dia", dayofmonth(df["data_pregao"]))
            df.write.mode("overwrite").partitionBy("ano", "mes", "dia")\
                .parquet(self.output_path + "acao_pregao")
            return df
        except Exception as e:
            print("[write_parquet_to_s3] Erro na gravação dos dados: (e)")
            raise

    def update_glue_catalog(self, df):
        try:
            dynamic_frame = DynamicFrame.fromDF (df, self.glueContext, "acao_pregao_b3")
            self.glueContext.write_dynamic_frame.from_options(
                frame=dynamic_frame, connection_type="s3", 
                connection_options={
                    "path": self.output_path + "acao_pregao",
                    "partitionKeys": ["ano", "mes", "dia"]
                },
                format="parquet",
                format_options={"compression": "SNAPPY"}
            )
            print("Glue Catalog atualizado com sucesso.")
        except Exception as e:
            print("[update_glue_catalog] Erro ao atualizar o Glue Catalog: {e}")
            raise