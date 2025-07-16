###################################################################################################################
# Este script é um job de ETL (Extract, Transform, Load) para processar dados da B3 (Bolsa de Valores do Brasil). #
# Ele lê dados de ações da B3 em formato Parquet, realiza transformações nos dados,                               #
# grava os dados transformados e particionados no S3                                                              #
# e atualiza o catálogo do Glue com a nova tabela criada para acesso as consultas no AWS Athena.                  #
###################################################################################################################

from pyspark.sql import SparkSession
from awsglue.context import GlueContext
from awsglue.transforms import *
from awsglue.dynamicframe import DynamicFrame
from awsglue.utils import getResolvedOptions
from awsglue.job import Job
from pyspark.sql.functions import year, month, dayofmonth,to_date,regexp_replace,col,current_date, lpad
import boto3
import time
import sys

###### Habilitar caso tenha subido via esteira git ###### 

#from modulos.catalog_glue_table import CatalogGlueTable 

class JobELTB3:
    def __init__(self, spark, glueContext, input_path, output_path, database_name,table_name, output_table_name,output_bucket,region='sa-east-1'):
        self.spark = spark
        self.glueContext = glueContext
        self.input_path = input_path
        self.output_path = output_path
        self.database_name = database_name
        self.table_name = table_name
        self.output_table_name = output_table_name
        self.output_bucket =output_bucket
        self.region=region
        self.client = boto3.client('athena', region_name=self.region)
        
    def read_parquet_from_s3(self):
        print(f"Lendo os dados do S3: {self.input_path}")
        try:
            df = self.spark.read.parquet(self.input_path)
            print("Dados lidos com sucesso do S3.")
            
            return df
        except Exception as e:
            print(f"[read_parquet_from_s3] Erro ao ler parquet: {e}")
            raise

    def write_parquet_to_s3(self, df):
        try:
            df.write\
              .mode("overwrite")\
              .option("partitionOverwriteMode", "DYNAMIC") \
              .partitionBy("ano", "mes", "dia")\
              .parquet(f"{self.output_path}{self.output_table_name}")
            
            print("Gravação dos dados realizado com sucesso.")

            return df
        except Exception as e:
            print(f"[write_parquet_to_s3] Erro na gravação dos dados : {e}")
            raise

    def update_glue_catalog(self, df):
      try:
          spark = self.glueContext.spark_session
          spark.conf.set("spark.sql.sources.partitionOverwriteMode", "dynamic")

          print(f"Constructed output path for saveAsTable: {self.output_path}")  # Debugging
          print(f"Database: {self.database_name}, Table: {self.output_table_name}")  # Debugging
          print(f"Initiating dynamic partition overwrite for table '{self.database_name}.{self.output_table_name}'...")

          df.write \
          .mode("overwrite") \
          .format("parquet") \
          .partitionBy("ano", "mes", "dia", "data_pregao") \
          .option("path", self.output_path) \
          .saveAsTable(f"{self.database_name}.{self.output_table_name}") 
          print(f"Data saved to '{self.output_path}' and catalog '{self.database_name}.{self.output_table_name}' updated successfully.")

      except Exception as e:
          print(f"[update_glue_catalog] Error overwriting data and updating catalog: {e}")
          raise


    def adicionar_data_pregao(self,df):
        # Adiciona a data do pregão baseada na data atual da execução
        df_partition = df.withColumn("data_pregao", to_date(current_date(), "yyyy-MM-dd"))
        return df_partition


    def transform_dataframe(self, df):
        try:
            print("Iniciando tratamento rename columns ...")
            df_renamed = df.withColumnRenamed("segment", "segmento") \
                           .withColumnRenamed("cod", "codigo_bovespa") \
                           .withColumnRenamed("asset", "nome_acao") \
                           .withColumnRenamed("type", "nome_tipo_acao") \
                           .withColumnRenamed("part", "percentual_participacao_acao") \
                           .withColumnRenamed("partacum", "percentual_participacao_acumulada") \
                           .withColumnRenamed("theoricalqty", "quantidade_teorica")
    
            print("Iniciando conversão de tipos e limpeza...")
            df_transformed = df_renamed \
                .withColumn("quantidade_teorica", regexp_replace(col("quantidade_teorica"), "\\.", "").cast("decimal(18,0)")) \
                .withColumn("percentual_participacao_acumulada", regexp_replace(col("percentual_participacao_acumulada"), ",", ".").cast("decimal(18,3)")) \
                .withColumn("percentual_participacao_acao", regexp_replace(col("percentual_participacao_acao"), ",", ".").cast("decimal(18,3)")) \
                .withColumn("ano", col("ano").cast("string")) \
                .withColumn("mes", lpad(col("mes").cast("string"), 2, '0')) \
                .withColumn("dia", lpad(col("dia").cast("string"), 2, '0'))
    
            # As colunas de string não precisam de cast explícito se já foram lidas como string.
            # Ex: .withColumn("segmento", col("segmento").cast("string"))
    
            return df_transformed
        except Exception as e:
            print(f"Erro na etapa de tratamento do dataframe: {e}")
            raise

    def run(self):
        try:
            df_full_b3 = self.read_parquet_from_s3()
            df_full_b3 = self.adicionar_data_pregao(df_full_b3)
            df_full_b3 = self.transform_dataframe(df_full_b3)
            #self.write_parquet_to_s3(df_full_b3)
            df_full_b3.show()
            # O método update_glue_catalog não precisa mais do dataframe
            self.update_glue_catalog(df_full_b3)

        except Exception as e:
            print(f"Erro ao executar o job: {e}")
            raise

if __name__ == "__main__":
    # Lendo argumentos passados pelo Terraform para desacoplar o código da infraestrutura
    args = getResolvedOptions(sys.argv, ['JOB_NAME',
                                         'INPUT_PATH',
                                         'OUTPUT_PATH',
                                         'DATABASE_NAME',
                                         'TABLE_NAME',
                                         'OUTPUT_TABLE_NAME',
                                         'ATHENA_OUTPUT_BUCKET'])
    spark = SparkSession.builder.appName("job_elt_b3").getOrCreate()
    glueContext = GlueContext(spark)
    job = Job(glueContext)
    job.init(args['JOB_NAME'], args)

    print("Glue Job iniciado com sucesso")

    # Instanciando a classe com os argumentos dinâmicos
    job_b3 = JobELTB3(spark, glueContext,
                      args['INPUT_PATH'],
                      args['OUTPUT_PATH'],
                      args['DATABASE_NAME'],
                      args['TABLE_NAME'],
                      args['OUTPUT_TABLE_NAME'],
                      args['ATHENA_OUTPUT_BUCKET'])
    job_b3.run()

    job.commit()