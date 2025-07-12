import requests
import pandas as pd
import base64
import json
import os
from datetime import datetime
import boto3 

def lambda_handler(event=None, context=None):
    # URL base da API. A parte final é um parâmetro codificado em base64.
    api_params = {
        "language": "pt-br",
        "pageNumber": 1,
        "pageSize": 150,
        "index": "IBOV",
        "segment": "1"
    }

    # Permite que os parâmetros sejam configurados via evento Lambda
    if event and isinstance(event, dict):
        api_params.update(event.get('api_params', {}))

    # Codifica os parâmetros em base64
    encoded_params = base64.b64encode(json.dumps(api_params).encode('utf-8')).decode('utf-8')

    # Constrói a URL da API com os parâmetros codificados
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

            # --- Lógica para salvar em Parquet no S3 usando /tmp e boto3 ---
            s3_bucket_name = os.environ.get('S3_BUCKET_NAME') # Obter do ambiente, sem valor padrão 'seu-bucket-s3-aqui'
            
            if not s3_bucket_name:
                print("ERRO: A variável de ambiente 'S3_BUCKET_NAME' não foi configurada.")
                return {
                    'statusCode': 500,
                    'body': json.dumps({"message": "Nome do bucket S3 não configurado. Por favor, defina a variável de ambiente 'S3_BUCKET_NAME'."})
                }

            # Obtém a data atual para a estrutura de diretórios
            now = datetime.now()
            year = now.year
            month = now.month
            day = now.day

            # Constrói o caminho do arquivo no S3
            s3_key = f"ibov_data/year={year}/month={month:02d}/day={day:02d}/data.parquet"
            
            # Define o caminho temporário no sistema de arquivos da Lambda
            temp_file_path = f"/tmp/ibov_data_{now.strftime('%Y%m%d%H%M%S')}.parquet"

            print(f"Salvando dados temporariamente em: {temp_file_path}")
            df.to_parquet(temp_file_path, index=False) # Salva no /tmp

            # Inicializa o cliente S3
            s3_client = boto3.client('s3')

            print(f"Fazendo upload de {temp_file_path} para s3://{s3_bucket_name}/{s3_key}")
            s3_client.upload_file(temp_file_path, s3_bucket_name, s3_key)

            # Opcional: Remover o arquivo temporário após o upload
            os.remove(temp_file_path)
            print(f"Arquivo temporário {temp_file_path} removido.")

            return {
                'statusCode': 200,
                'body': json.dumps({"message": f"Dados raspados e salvos com sucesso em s3://{s3_bucket_name}/{s3_key}"})
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