# Tech Challenge 2 (Fase 2): Pipeline Batch Bovespa: Ingestão e Arquitetura de dados


**Tech Challenge** é um projeto que reúne a aplicação dos conhecimentos adquiridos em todas as disciplinas de uma fase da Especialização em Machine Learning Engineering da FIAP PosTech.

Para o Tech Challenge 2, o desafio proposto foi o seguinte:

> 📢 **Problema:** construa um pipeline de dados completo para **Extrair, Processar e Analisar dados do pregão da B3 (IBovespa)**, utilizando AWS S3, Glue, Lambda e Athena. Para acessar os dados, obrigatoriamente acessar o link: [Carteira Teórica o IBovespa](https://sistemaswebb3-listados.b3.com.br/indexPage/day/IBOV?language=pt-br)

Para este desafio as entregas devem ser realizadas utilizando tecnologias da **Amazon Cloud** e atender aos seguintes **Requisitos/objetivos**:

• **Requisito 1:** realizar o scrap de dados do site da B3 (IBovespa), extraindo dados do pregão (dados brutos).

• **Requisito 2:** os dados brutos devem ser ingeridos no S3 em formato parquet com partição diária.

• **Requisito 3:** o Bucket S3 deve acionar uma Lambda, que por sua vez irá chamar um job de ETL no Glue.

• **Requisito 4:** a Lambda pode ser em qualquer linguagem. Ela apenas deverá iniciar o job Glue.

• **Requisito 5:** o job Glue deve ser feito no modo visual. Este job deve conter as seguintes transformações obrigatórias:

5.a: Realizar agrupamento numérico, sumarização, contagem ou soma;

5.b: Renomear duas colunas existentes, além das colunas de agrupamento;

5.c: Realizar um cálculo com campos de data; por exemplo, poder ser duração, comparação ou diferença entre datas.

• **Requisito 6:** os dados refinados no job Glue devem ser salvos no formato parquet em uma pasta chamada REFINED, particionados por data e pelo nome ou abreviação da ação do pregão.

• **Requisito 7:** o job Glue deve automaticamente catalogar o dado no Glue Catalog e criar uma tabela no banco de dados default do Glue Catalog.

• **Requisito 8:** os dados devem estar disponíveis e legíveis no Athena.

• **Requisito 9:** (OPCIONAL) construir um notebook no Athena para realizar uma visualização gráfica dos dados ingeridos.

• **Requisito 10:** (OPCIONAL) construir uma Pipeline Stream Bitcoin, conforme arquitetura de referência fornecida.

## 📌 Objetivos

- Elaborar a **Arquitetura do projeto**, demonstrando todas as fases da pipeline;
- Implementar as tecnologias para o atendimento dos requisitos da Pipeline de Ingestão de Dados da B3;
- Documentar o projeto de forma a permitir a sua reprodução;
- Disponibilizar a documentação em um repositório no **GitHub**.

## Possíveis dores

- Falta de automação na obtenção dos dados bem como seu tratamento;
- Falta de padronização para acesso aos dados bem como tipos de retornos e formatos mais adequados para consumo na produção de consultas e analytics;
- Suporte e documentação insuficientes;
- Redundância de dados em histórico confiável, com fonte de dados própria;
- Baixa capacidade de análise em questões relevantes para o usuário final.

## Proposta de solução

Em face ao desafio proposto, algumas funcionalidades propostas (stages) para a Pipeline Batch Bovespa:

- Ingestão de dados: coleta automática de dados (webscraping) extraídos do site B3 (IBovespa), por meio de script em Lambda trigado pelo Event Bridge;
- Armazenamento de dados: salvamento em formato bruto (RAW), com partição diária, em Bucket S3;
- Processamento: limpeza, transformação e padronização, usando script em Glue acionado pela Lambda e trigado por Event Bridge;
- Carga final: gravação de dado procesado (REFINED), com partição diária, em Bucket S3;
- Agregações e Cálculos: agregações e cálculos, usando script em Glue, para análise do comportamento dos dados;
- Consumo: leitura dos dados refinados e agregados para a produção de relatórios e dashboards, usando Athena e Google Colab.



**Importante**

Toda a implementação foi feita via Terraform, portanto, com o princípio de **Infrastructure as a Code** e foi documentada neste repositório.



### 📂 Estrutura do projeto

(inserir)

### 🔩 Arquitetura da solução

A arquitetura da solução foi desenhada com base nos stages necessários ao atendimento de requisitos e consta na pasta de documentação deste repositório. [Link para o Diagrama](inserir figura e link)

## Documentação Terraform

```

# terraform-infra-pipeline-aws

# ![logo61](docs/imagens/logo.png) 
  # Sobre o Projeto

**Tech Challenge** é um projeto que reúne a aplicação dos conhecimentos adquiridos em todas as disciplinas na segunda fase da Especialização em Machine Learning Engineering da FIAP PosTech.

Para o Tech Challenge 2, o desafio proposto foi o seguinte:

> 📢 **Problema:** Construa um pipeline de dados completo para extrair, processar e 
analisar dados do pregão da B3, utilizando AWS S3, Glue, Lambda e Athena. 

**Link do site:** [B3](https://sistemaswebb3-listados.b3.com.br/indexPage/day/IBOV?language=pt-br)

**Proposta do desafio:**
A proposta do projeto é criar projeto na plataforma **AWS Cloud** para realizar um fluxo de ETL e consulta nos dados disponíveis no site da B3 :

- Carteira Teórica do IBovespa

A API desenvolvida será utilizada para alimentar uma base de dados que servirá para o processo de ETL com os serviços da **AWS Cloud**.

## 📌 Objetivos
Automatizar o processo de extração, ingestão, processamento e análise de dados do pregão da B3, utilizando serviços AWS escaláveis e serverless:
- Extrair (scraping) dados do site da B3.
- Ingerir e armazenar esses dados em um bucket S3 em formato otimizado (parquet), com partições diárias.
- Orquestrar o processamento com Lambda e Glue (ETL visual).
- Refinar e transformar os dados com operações de agregação, renomeação de colunas e manipulação de datas.
- Catalogar automaticamente os dados no Glue Catalog.
- Consultá-los facilmente com Athena.


## Possíveis dores

🕸️ 1. Scraping instável
  - O site da B3 pode mudar de estrutura ou bloquear requisições automatizadas.
  - Restrições de CORS ou autenticação podem exigir técnicas avançadas.
  - Manuseio de diferentes formatos (CSV, XLSX, ZIP) é comum e precisa de tratamento.
📦 2. Ingestão no S3
  - Garantir que os dados estejam no formato parquet com partição por data exige cuidado com o nome dos arquivos e a estrutura de diretórios.
  - Falhas de autenticação (credenciais IAM mal configuradas) podem impedir uploads.
🔁 3. Orquestração via Lambda
  - A função Lambda precisa lidar com erros e timeouts, especialmente ao chamar o Glue.
  - Limites de tempo da Lambda (máx 15 min) podem afetar sua funcionalidade.
🧪 4. ETL no Glue 
  - Operações como agregações e cálculos entre datas exigem compreensão do formato dos dados.
  - Glue cobra por tempo de execução — transformações ineficientes podem custar mais!
🧭 5. Particionamento refinado
    - Particionar por data + nome da ação exige manipulação correta do schema.
    - Se o nome da ação estiver mal formatado, pode quebrar a lógica de partição.
📚 6. Catalogação e Athena
    - O Glue Catalog pode não registrar corretamente se os arquivos estiverem com metadados inconsistentes.
    - Athena exige que partições estejam bem definidas para conseguir consultas rápidas e sem erro.


## Proposta de solução

Em face ao desafio proposto, algumas funcionalidades propostas para a API são:

1. Extração de Dados (Scraping)
- Implementar um script (Python ou Node.js) que realiza o scraping dos dados do pregão da B3 a partir do link fornecido.
- Salvar os dados em formato CSV/JSON localmente para tratamento inicial.
- Automatizar execução via CloudWatch Events ou manualmente.
2. Ingestão no Amazon S3
- Após o scraping, os dados são salvos no Amazon S3 em formato Parquet, particionados por data do pregão (YYYY-MM-DD).
3. Disparo da Função Lambda
- Configurar evento S3 para acionar uma função Lambda após upload dos dados.
- A Lambda, escrita em qualquer linguagem (sugestão: Python ou Node.js), apenas inicia o job do AWS Glue (usando boto3 ou SDK da AWS).

4. Transformação com AWS Glue
- Criar job Glue com as seguintes transformações:
    - Agregação: total de negociações por ação.
    - Renomear colunas: exemplo, vl_negociado → valor_total, qtd_negocios → quantidade.
    - Cálculo temporal: diferença entre data do pregão e data de liquidação, ou conversão de string para tipo timestamp.
    - Catalogação Automática no Glue
    - Glue adiciona os dados automaticamente no Glue Catalog sob o database default.
    - Criação da tabela com schema compatível e partições por data e sigla_acao.
    - Consulta com Amazon Athena
    - Athena habilitado para consulta SQL sobre os dados refinados.
    - Queries para análise de ações com maior volume, maior variação, etc.


## 📂 Estrutura do projeto

```
  
```


## 🔩 Arquitetura da solução

A arquitetura da solução foi desenhada sob uma abordagem End-to-end e consta na pasta de documentação deste repositório. [Link para o Diagrama] 


## Cenários de Machine Learning


## Dependências

Para o desenvolvimento deste desafio, foram utilizadas as seguintes bibliotecas e frameworks:



## 🛠️ Instalação do projeto local

Clonando o projeto localmente

``` bash
$ git clone 
```

Criando um ambiente virtual

``` bash
$ python -m venv venv
```

Ativando o ambiente virtual

``` bash
$ source venv/Scripts/activate 
```

Instalação das depêndências

``` bash
$ pip install -r api/requirements.txt
```
[Link para baixar requirements.txt] 

Executando o servidor Flask a partir do diretório raiz do projeto:

``` bash
$ cd api
$ flask run 
```

Ou executar com o debug ativado:

``` bash
$ cd api
$ flask run --debug
```

Testando as consultas localmente via Insomnia a seguir.


## 🌐 Lambda


## 📜 Glue

## Catalog do Glue

## S3 

## Athena




### ⚙️ Configuração 


## Testes Unitários
- Com as bibliotecas `pytest` e `unittest` instaladas
- Executar o seguinte comando no terminal na raiz do projeto
- 

```bash
$ cd api
$ python -m pytest
```





## Vídeo de Apresentação no Youtube
Para melhor compreensão da entrega, foi produzido um vídeo de apresentação que foi publicado no Youtube:


Feito isso, criar o arquivo .github/workflows/terraform.yaml, .github/workflows/develop.yaml, .github/workflows/prod.yaml

## Vídeo de Apresentação no Youtube
Para melhor compreensão da entrega, foi produzido um vídeo de apresentação que foi publicado no Youtube:

[Link para a Vídeo](inserir link)


## ✒️ Autores

| Nome                            |   RM    | Link do GitHub                                      |
|---------------------------------|---------|-----------------------------------------------------|
| Ana Paula de Almeida            | 363602  | [GitHub](https://github.com/Ana9873P)               |
| Augusto do Nascimento Omena     | 363185  | [GitHub](https://github.com/AugustoOmena)           |
| Bruno Gabriel de Oliveira       | 361248  | [GitHub](https://github.com/brunogabrieldeoliveira) |
| José Walmir Gonçalves Duque     | 363196  | [GitHub](https://github.com/WALMIRDUQUE)            |
| Pedro Henrique da Costa Ulisses | 360864  | [GitHub](https://github.com/ordepzero)              |

## 📄 Licença


Este projeto está licenciado sob a Licença MIT.  
Consulte o arquivo [license](docs/license/license.txt)  para mais detalhes.