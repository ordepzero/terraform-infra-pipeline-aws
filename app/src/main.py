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
            
            # Escreve os dados particionados. O caminho final será output_path + table_name
            df.write\
              .mode("overwrite")\
              .option("partitionOverwriteMode", "DYNAMIC") \
              .partitionBy("ano", "mes", "dia")\
              .parquet(f"{self.output_path}{self.table_name}")
            
            print("Gravação dos dados realizado com sucesso.")

            return df
        except Exception as e:
            print(f"[write_parquet_to_s3] Erro na gravação dos dados : {e}")
            raise

    def update_glue_catalog(self):
        try:
            print("Iniciando atualização do catálogo Glue via MSCK REPAIR...")
            # A escrita de dados já foi feita. Agora, apenas reparamos a tabela
            # para que o Glue descubra as novas partições escritas no S3.
            # Usar backticks (`) é uma boa prática para nomes de tabelas e bancos de dados.
            query = f'MSCK REPAIR TABLE `{self.database_name}`.`{self.table_name}`;'
            
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
                    if state == 'FAILED':
                        reason = status['QueryExecution']['Status'].get('StateChangeReason')
                        print(f"Motivo da falha: {reason}")
                    break
                time.sleep(2)
            
            print("Catálogo atualizado com sucesso.")
        except Exception as e:
            print(f"[update_glue_catalog] Erro ao atualizar/criar o catálogo: {e}")
            raise

    def adicionar_data_pregao(self,df):
        # Adiciona a data do pregão baseada na data atual da execução
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

    def run(self):
        try:
            df_full_b3 = self.read_parquet_from_s3()
            df_full_b3 = self.adicionar_data_pregao(df_full_b3)
            df_full_b3 = self.transform_dataframe(df_full_b3)
            self.write_parquet_to_s3(df_full_b3)
            
            # O método update_glue_catalog não precisa mais do dataframe
            self.update_glue_catalog()

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
                                         'ATHENA_OUTPUT_BUCKET'])
    spark = SparkSession.builder.appName("job_elt_b3").getOrCreate()
    glueContext = GlueContext(spark)
    job = Job(glueContext)
    job.init(args['JOB_NAME'], args)

    # Instanciando a classe com os argumentos dinâmicos
    job_b3 = JobELTB3(spark, glueContext,
                      args['INPUT_PATH'],
                      args['OUTPUT_PATH'],
                      args['DATABASE_NAME'],
                      args['TABLE_NAME'],
                      args['ATHENA_OUTPUT_BUCKET'])
    job_b3.run()

    job.commit()