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
from pyspark.sql.functions import year, month, dayofmonth,to_date,regexp_replace,col,current_date
import boto3
import time
import sys

###### Habilitar caso tenha subido via esteira git ###### 

#from modulos.catalog_glue_table import CatalogGlueTable 

#######################################################################
# Variavéis dos repositórios
#######################################################################
input_path = "s3://prod-sa-east-1-bovespa-raw/"
output_path = "s3://prod-sa-east-1-bovespa-refined/"
database_name = "tech_challenge"
table_name = "b3_acao_pregao"
output_bucket = "s3://analistadev-athena-output/"

class JobELTB3:
    def __init__(self, spark, glueContext, input_path, output_path, database_name,table_name,output_bucket,region='sa-east-1'):
        self.spark = spark
        self.glueContext = glueContext
        self.input_path = input_path
        self.output_path = output_path
        self.database_name = database_name
        self.table_name = table_name
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
            df = df.withColumn("ano", year(col("data_pregao"))) \
                   .withColumn("mes", month(col("data_pregao"))) \
                   .withColumn("dia", dayofmonth(col("data_pregao")))
            
            df.write\
              .mode("overwrite")\
              .option("partitionOverwriteMode", "DYNAMIC") \
              .partitionBy("ano", "mes", "dia")\
              .parquet(self.output_path + "b3_acao_pregao")
            
            print("Gravação dos dados realizado com sucesso.")

            return df
        except Exception as e:
            print(f"[write_parquet_to_s3] Erro na gravação dos dados : {e}")
            raise

    def update_glue_catalog(self, df):
        try:
            print("Iniciando atualização do catálogo Glue ...")
            dynamic_frame = DynamicFrame.fromDF(df, self.glueContext, "dynamic_frame")
                        
            self.glueContext.write_dynamic_frame.from_catalog(
                frame=dynamic_frame,
                database=self.database_name,
                table_name=self.table_name,
                additional_options={
                    "partitionKeys": ["ano", "mes", "dia"]
                }
            )
            
            query = f"MSCK REPAIR TABLE {self.table_name};"
            response = self.client.start_query_execution(
                QueryString=query,
                QueryExecutionContext={'Database': self.database_name},
                ResultConfiguration={'OutputLocation': self.output_bucket}
            )
    
            execution_id = response['QueryExecutionId']
            print(f"Executando MSCK REPAIR TABLE... ID da execução: {execution_id}")
            
            while True:
                status = self.client.get_query_execution(QueryExecutionId=execution_id)
                state = status['QueryExecution']['Status']['State']
                if state in ['SUCCEEDED', 'FAILED', 'CANCELLED']:
                    print(f" Status da execução Athena: {state}")
                    break
                time.sleep(2)
            
            print("Catálogo atualizado com sucesso.")
        except Exception as e:
            print(f"[update_glue_catalog] Erro ao atualizar/criar o catálogo: {e}")
            raise

    def adicionar_data_pregao(self,df):

        df_partition = df.withColumn("data_pregao", to_date(current_date(), "yyyy-MM-dd"))

        return df_partition


    def transform_dataframe(self, df):
        try:
            print("Iniciando tratamento rename columns ...")
            df = df.withColumnRenamed("Código", "codigo_bovespa") \
                   .withColumnRenamed("Ação", "nome_acao") \
                   .withColumnRenamed("tipo", "nome_tipo_acao") \
                   .withColumnRenamed("Qtde. Teórica", "quantidade_teorica") \
                   .withColumnRenamed("Part. (%)", "percentual_participacao_acao")
            

            print("types columns ...")
            df = df.withColumn("codigo_bovespa", df["codigo_bovespa"].cast("string")) \
                   .withColumn("nome_acao", df["nome_acao"].cast("string")) \
                   .withColumn("nome_tipo_acao", df["nome_tipo_acao"].cast("string")) \
                   .withColumn("quantidade_teorica", df["quantidade_teorica"].cast("decimal(18,2)")) \
                   .withColumn("percentual_participacao_acao",regexp_replace(col("percentual_participacao_acao"), ",", ".").cast("decimal(18,2)"))
                   
            return df
        except Exception as e:
            print(f"Erro na etapa de tratamento do dataframe: {e}")
            raise

    def grouped_df(self, df):
        try:
            print("Iniciando o agrupamento e contagem ...")
            grouped_df = df.groupBy("codigo_bovespa", "nome_tipo_acao","data_pregao").count()
            return grouped_df
        except Exception as e:
            print(f"Erro ao agrupar o dataframe: {e}")
            raise

    def run(self):
        try:
            df_full_b3 = self.read_parquet_from_s3()
            df_full_b3 = self.adicionar_data_pregao(df_full_b3)
            df_full_b3 = self.transform_dataframe(df_full_b3)
            df_full_b3 = self.write_parquet_to_s3(df_full_b3)
            
            ##### Habilitar caso tenha subido via esteira git ######
            #manager_glueTable = CatalogGlueTable(self.database_name, self.table_name, self.output_path + "acao_pregao_b3")
            #if not manager_glueTable.check_table_exists():
            #    manager_glueTable.create_table()
            
            self.update_glue_catalog(df_full_b3)

        except Exception as e:
            print(f"Erro ao executar o job: {e}")
            raise

if __name__ == "__main__":
    args = getResolvedOptions(sys.argv, ['JOB_NAME'])
    spark = SparkSession.builder.appName("job_elt_b3").getOrCreate()
    glueContext = GlueContext(spark)
    job = Job(glueContext)
    job.init(args['JOB_NAME'], args)

    job_b3 = JobELTB3(spark, glueContext, input_path, output_path, database_name, table_name,output_bucket)
    job_b3.run()

    job.commit()