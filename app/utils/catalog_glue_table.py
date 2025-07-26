###################################################################################################################
# Este script responsável por criar uma tabela no catálogo do AWS Glue                                            #
# Definindo a estrutura da tabela, incluindo colunas, tipos de dados e partições.                                 #
###################################################################################################################

import boto3
from botocore.exceptions import ClientError

class CatalogGlueTable:
    def __init__(self, database_name, table_name, output_path, region='sa-east-1'):
        self.database_name = database_name
        self.table_name = table_name
        self.output_path = output_path
        self.region = region
        self.glue = boto3.client('glue', region_name=self.region)

    def check_table_exists(self):
        try:
            self.glue.get_database(Name=self.database_name)
            print(f"Banco de dados '{self.database_name}' existe")
            
            self.glue.get_table(DatabaseName=self.database_name, Name=self.table_name)
            print(f"[CatalogGlueTable] Tabela '{self.table_name}' já existe no banco '{self.database_name}'.")
            return True
        except ClientError as e:
            if e.response['Error']['Code'] == 'EntityNotFoundException':
                print(f"[CatalogGlueTable] Tabela '{self.table_name}' NÃO existe no banco '{self.database_name}'.")
                return False
            else:
                print(f"[CatalogGlueTable] Erro ao verificar existência da tabela: {e}")
                raise

    def catalog_create_table(self):
        print(f"[CatalogGlueTable] Criando tabela '{self.table_name}' no catálogo Glue ...")
        try:
            self.glue.create_table(
                DatabaseName=self.database_name,
                TableInput={
                    'Name': self.table_name,
                    'Description': 'Tabela com dados de ações da B3 por pregão',
                    'StorageDescriptor': {
                        'Columns': [
                            {'Name': 'codigo_bovespa', 'Type': 'string'},
                            {'Name': 'nome_acao', 'Type': 'string'},
                            {'Name': 'nome_tipo_acao', 'Type': 'string'},
                            {'Name': 'quantidade_teorica', 'Type': 'decimal(18,2)'},
                            {'Name': 'percentual_participacao_acao', 'Type': 'decimal(18,2)'},
                            {'Name': 'data_pregao', 'Type': 'date'}
                        ],
                        'Location': self.output_path,
                        'InputFormat': 'org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat',
                        'OutputFormat': 'org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat',
                        'Compressed': False,
                        'SerdeInfo': {
                            'SerializationLibrary': 'org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe',
                            'Parameters': {'serialization.format': '1'}
                        }
                    },
                    'PartitionKeys': [
                        {'Name': 'ano', 'Type': 'int'},
                        {'Name': 'mes', 'Type': 'int'},
                        {'Name': 'dia', 'Type': 'int'}
                    ],
                    'TableType': 'EXTERNAL_TABLE',
                    'Parameters': {
                        'classification': 'parquet',
                        'EXTERNAL': 'TRUE'
                    }
                }
            )
            print(f"[CatalogGlueTable] Tabela '{self.table_name}' criada com sucesso!")
        except Exception as e:
            print(f"[CatalogGlueTable] Erro ao criar tabela: {e}")
            raise

##### comentar caso tenha subido via esteira git ######
# Este trecho é para executar o script diretamente no terminal

if __name__ == "__main__":
    output_path = "s3://prod-sa-east-1-bovespa-refined/b3_acao_pregao/"
    database_name = "tech_challenge"
    table_name = "b3_acao_pregao"

    creator = CatalogGlueTable(database_name, table_name, output_path)
    if not creator.check_table_exists():
       print("Inciando processo de criação da tabela")     
       creator.catalog_create_table()
       
    else:
        print(f"[CatalogGlueTable] A tabela '{table_name}' já existe no banco '{database_name}'.")