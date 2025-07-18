import json
import boto3
import os
import urllib.parse

glue = boto3.client('glue')

def lambda_handler(event, context):
    glue_job_name = os.environ.get('GLUE_JOB_NAME')

    # Extract bucket and object key from the S3 event
    for record in event.get('Records', []):
        s3_info = record.get('s3', {})
        bucket_name = s3_info.get('bucket', {}).get('name')
        encoded_key = s3_info.get('object', {}).get('key')
        
        if not bucket_name or not encoded_key:
            print("Bucket ou chave não encontrados no registro do evento. Pulando.")
            continue

        # Decodifica a chave do objeto S3 (ex: converte %3D para =)
        object_key = urllib.parse.unquote_plus(encoded_key)
        
        # OBTÉM O DIRETÓRIO DA PARTIÇÃO, NÃO O CAMINHO DO ARQUIVO.
        # Isso permite que o Spark infira as colunas de partição (ano, mes, dia) da estrutura de pastas.
        partition_directory = os.path.dirname(object_key)
        
        # Constrói o caminho completo do S3 para o DIRETÓRIO da partição
        s3_source_path = f"s3://{bucket_name}/{partition_directory}/"

        try:
            # Start Glue job
            response = glue.start_job_run(
                JobName=glue_job_name,
                Arguments={'--INPUT_PATH': s3_source_path} # Sobrescreve o argumento padrão com o caminho do DIRETÓRIO da partição
            )
            print(f"Job do Glue iniciado: {response['JobRunId']} para a partição: {s3_source_path}")
        except Exception as e:
            print(f"Erro ao iniciar o job do Glue: {e}")
            raise e

    return {
        'statusCode': 200,
        'body': json.dumps('Glue job triggered successfully.')
    }