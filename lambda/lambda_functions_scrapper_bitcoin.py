import requests
from bs4 import BeautifulSoup
import re

def extrair_cotacao_bitcoin():
    """
    Extrai a cotação atual do Bitcoin (BTC/BRL) da página do Investing.com.

    Returns:
        float: O valor da cotação como um número float, ou None se ocorrer um erro.
    """
    url = "https://br.investing.com/crypto/bitcoin/btc-eur"
    
    # É crucial enviar um cabeçalho User-Agent para simular um navegador real.
    # Muitos sites bloqueiam requisições que não parecem vir de um navegador.
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
    }

    try:
        print(f"Acessando a página: {url}")
        # Faz a requisição GET para obter o conteúdo da página
        response = requests.get(url, headers=headers)
        
        # Verifica se a requisição foi bem-sucedida (código de status 200)
        response.raise_for_status()
        print("Página acessada com sucesso.")

        # Cria um objeto BeautifulSoup para "ler" o HTML
        soup = BeautifulSoup(response.text, 'html.parser')

        # Encontra o elemento que contém o preço.
        # Inspecionando a página, vemos que o preço está em uma <div> com o atributo data-test="instrument-price-last".
        # Este é um seletor estável e ideal para scraping.
        price_element = soup.find('div', {'data-test': 'instrument-price-last'})

        if not price_element:
            print("Erro: Elemento do preço não encontrado na página. O site pode ter mudado sua estrutura.")
            return None

        # Extrai o texto do elemento (ex: "336.195,0")
        price_text = price_element.get_text()
        print(f"Texto do preço extraído: '{price_text}'")

        # Limpa o texto para converter em um número (float)
        # 1. Remove os pontos (.) que são separadores de milhar.
        # 2. Substitui a vírgula (,) por um ponto (.) para ser um decimal válido em Python.
        price_cleaned = price_text.replace('.', '').replace(',', '.')
        
        # Converte o texto limpo para float
        price_float = float(price_cleaned)
        
        print(f"Cotação do Bitcoin (BTC/BRL): R$ {price_float:,.2f}")
        
        return price_float

    except requests.exceptions.RequestException as e:
        print(f"Erro ao fazer a requisição HTTP: {e}")
        return None
    except (ValueError, AttributeError) as e:
        print(f"Erro ao processar o conteúdo da página ou converter o preço: {e}")
        return None

# Executa a função
if __name__ == "__main__":
    extrair_cotacao_bitcoin()
