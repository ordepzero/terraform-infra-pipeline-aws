import requests
import pandas as pd
import base64
import json
import os
from datetime import datetime
import boto3 # Importa a biblioteca boto3 para interagir com serviços AWS como S3 e Glue

# Inicializa o cliente Glue fora da função para reutilização (melhor prática em Lambda)
glue_client = boto3.client('glue')

def lambda_handler(event=None, context=None):
    """
    Função Lambda para fazer o scraping dos dados da carteira teórica do IBovespa da B3
    usando a API direta e salvar os dados em formato Parquet no S3,
    além de atualizar o AWS Glue Data Catalog de forma dinâmica.
    """
    api_params = {
        "language": "pt-br",
        "pageNumber": 1,
        "pageSize": 120,
        "index": "IBOV",
        "segment": "2"
    }

    if event and isinstance(event, dict):
        api_params.update(event.get('api_params', {}))

    encoded_params = base64.b64encode(json.dumps(api_params).encode('utf-8')).decode('utf-8')
    api_url = f'https://sistemaswebb3-listados.b3.com.br/indexProxy/indexCall/GetPortfolioDay/{encoded_params}'

    headers = {
        'accept': 'application/json, text/plain, */*',
        'accept-language': 'pt-BR,pt;q=0.9,en-US;q=0.8,en;q=0.7',
        'priority': 'u=1, i',
        'referer': 'https://sistemaswebb3-listados.b3.com.br/',
        'sec-ch-ua': '"Not)A;Brand";v="8", "Chromium";v="138", "Google Chrome";v="138"',
        'sec-ch-ua-mobile': '?0',
        'sec-ch-ua-platform': '"Windows"',
        'sec-fetch-dest': 'empty',
        'sec-fetch-mode': 'cors',
        'sec-fetch-site': 'same-origin',
        'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36',
    }

    cookies = {
        'dtCookie': 'v_4_srv_33_sn_EF806CE73FE8BBD5C0D54D237CBD205A_perc_100000_ol_0_mul_1_app-3Afd69ce40c52bd20e_1_rcs-3Acss_0',
        'TS01f22489': '011d592ce16320141a792061e1a696fbef13c9366c2502598ba5b2f594a78722fd9d91be276b04b12134b0a49acb8bee72e9594a3f',
        '__cf_bm': 'OB4vV2_4HEqWf1U4mQeMHvq8DgRU78IQMqvcJRMyL2w-1752197046-1.0.1.1-_Bnti5dOBgLhb9wFvxkOoofq7c6HHiK6bJPmn.d9P6Wf_5E17_RzBoii_ln4Ay4toEh_7xZrQZLh18AQoljr6QzKfGxUD3qN5kE3KKJfaNw',
        'rxVisitor': '175219705569175MI2Q1DBDQD8KEALKEF8CC4ITVPDBCU',
        'dtSa': '-',
        '_gid': 'GA1.3.1901695088.1752197056',
        '_gat_gtag_UA_94042116_5': '1',
        'cf_clearance': 'YlZoFB6yFHfTG1Iu.J3qI5tFP.5dAfnRWRJ5GR.KAMw-1752197047-1.2.1.1-pcf4maBLPXWuabusJ6tr.JukQZIVXVYORbQQqF48Srd0lL05eNVVDlXwEWT7zJMURnAoKXIGoOfCruWrfoC3yHtJFCSyEjRDzN58v0WQEBvF1p5CC7U_XBHsARSYRTb4Jn_beUsGCwUfl5gx6mic3kwvWS0.xV.BpOoBS2dBM2_ACTvcgrc8HP6_ssrJYlR1T_0MCrC_jNSDIzAUpZKsZNEviX7PgvmBpa9ds9eTS9w',
        '_ga_CNJN5WQC5G': 'GS2.1.s1752197056$o6$g0$t1752197056$j60$l0$h0',
        '_ga': 'GA1.1.1938705953.1748994657',
        'rxvt': '1752198856273|1752197055693',
        'dtPC': '33$197055688_265h-vKAGMFUKJLALWFRDSADNBQFGVTMOFAHOE-0e0'
    }

    try:
        print(f"Fazendo requisição para a API: {api_url}")
        response = requests.get(api_url, headers=headers, cookies=cookies)
        response.raise_for_status()

        data = response.json()

        if 'results' in data and data['results']:
            df = pd.DataFrame(data['results'])

            s3_bucket_name = os.environ.get('S3_BUCKET_NAME')
            
            if not s3_bucket_name:
                print("ERRO: A variável de ambiente 'S3_BUCKET_NAME' não foi configurada.")
                return {
                    'statusCode': 500,
                    'body': json.dumps({"message": "Nome do bucket S3 não configurado. Por favor, defina a variável de ambiente 'S3_BUCKET_NAME'."})
                }

            now = datetime.now()
            year = now.year
            month = now.month
            day = now.day
            
            # --- Adicionar lógica para atualizar o AWS Glue Data Catalog ---
            glue_database_name = os.environ.get('GLUE_DATABASE_NAME', 'raw_database_name') # Nome do seu banco de dados Glue
            glue_table_name = os.environ.get('GLUE_TABLE_NAME', 'tb_fiap_tech02_bovespa_raw') # Nome da sua tabela Glue

            # Define o caminho S3 para o arquivo Parquet
            s3_key_prefix = f"{glue_table_name}/ano={year}/mes={month:02d}/day={day:02d}/"
            s3_file_name = "data.parquet"
            s3_full_key = s3_key_prefix + s3_file_name
            
            temp_file_path = f"/tmp/{glue_table_name}_{now.strftime('%Y%m%d%H%M%S')}.parquet"

            print(f"Salvando dados temporariamente em: {temp_file_path}")
            df.to_parquet(temp_file_path, index=False)

            s3_client = boto3.client('s3')
            print(f"Fazendo upload de {temp_file_path} para s3://{s3_bucket_name}/{s3_full_key}")
            s3_client.upload_file(temp_file_path, s3_bucket_name, s3_full_key)

            os.remove(temp_file_path)
            print(f"Arquivo temporário {temp_file_path} removido.")

            print(f"Obtendo informações da tabela Glue '{glue_table_name}' no banco de dados '{glue_database_name}'...")
            table_info = None
            try:
                response_get_table = glue_client.get_table(
                    DatabaseName=glue_database_name,
                    Name=glue_table_name
                )
                table_info = response_get_table['Table']
                print("Informações da tabela obtidas com sucesso.")
            except glue_client.exceptions.EntityNotFoundException:
                print(f"ERRO: Tabela Glue '{glue_table_name}' não encontrada no banco de dados '{glue_database_name}'.")
                return {
                    'statusCode': 404,
                    'body': json.dumps({"message": f"Tabela Glue não encontrada: {glue_database_name}.{glue_table_name}"})
                }
            except Exception as get_table_e:
                print(f"ERRO ao obter informações da tabela Glue: {get_table_e}")
                return {
                    'statusCode': 500,
                    'body': json.dumps({"message": f"Erro ao obter informações da tabela Glue: {str(get_table_e)}"})
                }

            # Extrair colunas e chaves de partição dinamicamente
            table_columns = table_info['StorageDescriptor']['Columns']
            table_partition_keys = table_info.get('PartitionKeys', [])

            # Preparar valores das partições com base nas chaves de partição
            partition_values = []
            # Assumimos que as chaves de partição são 'year', 'month', 'day' nesta ordem
            # Se a ordem ou os nomes forem diferentes, esta lógica precisará ser ajustada
            # baseada em `table_partition_keys`.
            # Exemplo mais robusto:
            for pk in table_partition_keys:
                if pk['Name'] == 'ano':
                    partition_values.append(str(year))
                elif pk['Name'] == 'mes':
                    partition_values.append(f"{month:02d}")
                elif pk['Name'] == 'dia':
                    partition_values.append(f"{day:02d}")
                else:
                    # Lidar com outras chaves de partição se existirem
                    print(f"AVISO: Chave de partição '{pk['Name']}' não tratada explicitamente na lógica de valores.")
                    # Você pode adicionar um valor padrão ou levantar um erro
                    partition_values.append('unknown') # Ou levantar um erro

            print(f"Atualizando partição no Glue Catalog para {glue_database_name}.{glue_table_name} com valores: {partition_values}...")
            
            try:
                glue_client.create_partition(
                    DatabaseName=glue_database_name,
                    TableName=glue_table_name,
                    PartitionInput={
                        'Values': partition_values, # Usando valores de partição dinâmicos
                        'StorageDescriptor': {
                            'Location': f"s3://{s3_bucket_name}/{s3_key_prefix}", # Caminho S3 da partição
                            'InputFormat': table_info['StorageDescriptor']['InputFormat'], # Dinâmico
                            'OutputFormat': table_info['StorageDescriptor']['OutputFormat'], # Dinâmico
                            'SerdeInfo': table_info['StorageDescriptor']['SerdeInfo'], # Dinâmico
                            'Columns': table_columns # Usando colunas dinâmicas
                        }
                    }
                )
                print("Partição adicionada/atualizada no Glue Catalog com sucesso.")
            except glue_client.exceptions.AlreadyExistsException:
                print("Partição já existe no Glue Catalog. Nenhuma ação necessária.")
            except Exception as glue_e:
                print(f"ERRO ao atualizar o Glue Catalog: {glue_e}")
                return {
                    'statusCode': 500,
                    'body': json.dumps({"message": f"Dados salvos, mas erro ao atualizar Glue Catalog: {str(glue_e)}"})
                }
            # --- Fim da lógica de atualização do AWS Glue Data Catalog ---

            return {
                'statusCode': 200,
                'body': json.dumps({"message": f"Dados raspados e salvos com sucesso em s3://{s3_bucket_name}/{s3_full_key} e partição Glue atualizada."})
            }
        else:
            print("Erro: A chave 'results' não foi encontrada na resposta JSON ou está vazia.")
            print(f"Resposta JSON completa: {json.dumps(data, indent=2)}")
            return {
                'statusCode': 404,
                'body': json.dumps({"message": "Dados não encontrados ou estrutura inesperada."})
            }

    except requests.exceptions.RequestException as e:
        print(f"Erro ao fazer a requisição HTTP: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({"message": f"Erro de requisição HTTP: {str(e)}"})
        }
    except json.JSONDecodeError as e:
        print(f"Erro ao decodificar a resposta JSON: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({"message": f"Erro de decodificação JSON: {str(e)}", "response_content": response.text})
        }
    except Exception as e:
        print(f"Ocorreu um erro inesperado: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({"message": f"Erro inesperado: {str(e)}"})
        }

# Bloco para testar a função localmente, simulando uma invocação Lambda
if __name__ == "__main__":
    print("Testando a função Lambda localmente...")
    # Para testar localmente o salvamento em S3, você precisaria configurar
    # credenciais AWS no seu ambiente local (ex: variáveis de ambiente AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)
    # e ter o 'pyarrow' e 'boto3' instalados.
    
    # Defina um nome de bucket S3 para teste local (substitua por um bucket real que você tenha acesso)
    os.environ['S3_BUCKET_NAME'] = 'dev-533267324332-fiap-tc02-dados-brutos-bovespa' 
    os.environ['GLUE_DATABASE_NAME'] = 'raw_database_name' # Nome do seu banco de dados Glue para teste
    os.environ['GLUE_TABLE_NAME'] = 'tb_fiap_tech02_bovespa_raw' # Nome da sua tabela Glue para teste


    test_event = {} # Usar parâmetros padrão para a API

    response_from_lambda = lambda_handler(test_event, None)

    print("\nResposta da função Lambda:")
    print(json.dumps(response_from_lambda, indent=2))

    if response_from_lambda['statusCode'] == 200:
        print("\nOperação de scraping e salvamento em Parquet (simulada) concluída com sucesso.")
    else:
        print("\nA função Lambda retornou um erro durante o scraping ou salvamento.")
