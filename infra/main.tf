# Data source para obter a região atual
data "aws_region" "current" {}

# Data source para obter o ID da conta AWS (necessário para a política de logs)
data "aws_caller_identity" "current" {}

########################
###   RECURSOS S3    ###
########################
resource "aws_s3_bucket" "bucket_bovespa_raw" {
  bucket = var.bucket_name_bovespa_bruto
}

resource "aws_s3_bucket" "bucket_bovespa_refined" {
  bucket = var.bucket_name_bovespa_refinado
}

resource "aws_s3_bucket" "bucket_artefatos" {
  bucket = var.bucket_name_artefatos
}

##################################################
####   ARTEFATOS PYTHON PARA O GLUE JOB       ####
##################################################

# 1. Upload do script principal do Glue Job (etl_job.py)
# O script principal estará em 'app/src/etl_job.py' localmente.
resource "aws_s3_object" "glue_etl_script" {
  bucket = aws_s3_bucket.bucket_artefatos.id
  key    = "app/src/main.py"
  source = "${path.module}/../app/src/main.py" # Caminho local para o seu script principal
  etag   = filemd5("${path.module}/../app/src/main.py")
}

# 2. Criação do arquivo ZIP do diretório 'app/utils'
# Este data source cria um arquivo ZIP localmente.
data "archive_file" "python_utils_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../app/utils/" # Caminho local para o diretório de utilitários
  output_path = "app/utils.zip" # Nome do arquivo ZIP que será criado localmente
  # Garanta que o diretório 'app/utils' exista localmente
}


# 3. Upload do arquivo ZIP para o S3
# O arquivo ZIP será enviado para 'libraries/app_utils.zip' no bucket de artefatos.
resource "aws_s3_object" "glue_python_libraries" {
  bucket = aws_s3_bucket.bucket_artefatos.id
  key    = "utils.zip"
  source = data.archive_file.python_utils_zip.output_path # Caminho para o arquivo ZIP gerado
  etag   = filemd5(data.archive_file.python_utils_zip.output_path) # Garante que o S3 object seja atualizado se o zip mudar
}


############################
####   SECURITY GROUPS   ###
############################

resource "aws_security_group" "glue_job_security_group" {
  name        = "${var.environment}-glue-job-sg"
  description = "Security group for AWS Glue jobs in VPC"
  vpc_id      = var.vpc_id # Você precisará definir esta variável (o ID da sua VPC)

  tags = {
    Name = "${var.environment}-glue-job-sg"
  }
}

# Regra de Security Group para permitir todo o tráfego de entrada do próprio SG
# Isso é necessário para a comunicação interna dos componentes do Glue Job na VPC.
resource "aws_security_group_rule" "glue_self_ingress_all" {
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = -1 # -1 significa todos os protocolos
  security_group_id = aws_security_group.glue_job_security_group.id
  self              = true # Permite tráfego de e para o próprio Security Group
  description       = "Required for AWS Glue internal communication within VPC"
}

# Regra de Security Group para permitir todo o tráfego de saída
# Isso é comum para Glue Jobs, permitindo acesso a S3, CloudWatch, etc.
resource "aws_security_group_rule" "glue_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1" # -1 significa todos os protocolos
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.glue_job_security_group.id
  description       = "Allow all outbound traffic"
}

#################################
#### ROUTE TABLE ASSOCIATION ####
#################################

data "aws_subnet" "glue_job_subnet" {
  id = var.subnet_id # O ID da sub-rede do seu Glue Job
}


# Data source para obter a tabela de rotas da sub-rede do Glue Job
# Isso é necessário para associar o VPC Endpoint S3 à tabela de rotas correta.
data "aws_route_table" "glue_job_subnet_route_table" {
  vpc_id = data.aws_subnet.glue_job_subnet.vpc_id

  # Removendo o filtro "association.subnet-id" para focar na "main".
  filter {
    name   = "association.main"
    values = ["true"]
  }
}

# NOVO: VPC Endpoint de Gateway para S3
# Permite que o Glue Job acesse o S3 de dentro da VPC sem precisar de NAT Gateway ou Internet Gateway.
resource "aws_vpc_endpoint" "s3_gateway_endpoint" {
  vpc_id       = var.vpc_id
  service_name = "com.amazonaws.${data.aws_region.current.region}.s3"
  vpc_endpoint_type = "Gateway" # Tipo Gateway para S3

  # Associa o endpoint à tabela de rotas da sub-rede do Glue Job
  route_table_ids = [data.aws_route_table.glue_job_subnet_route_table.id]

  tags = {
    Name = "${var.environment}-s3-gateway-endpoint"
  }
}

# NOVO: VPC Endpoint de Interface para CloudWatch Logs
# Permite que o Glue Job envie logs de dentro da VPC.
resource "aws_vpc_endpoint" "logs_interface_endpoint" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.logs"
  vpc_endpoint_type = "Interface"

  subnet_ids         = [var.subnet_id]
  security_group_ids = [aws_security_group.glue_job_security_group.id]

  tags = {
    Name = "${var.environment}-logs-interface-endpoint"
  }
}

# NOVO: VPC Endpoint de Gateway para Athena
# Permite que o Glue Job execute queries no Athena de dentro da VPC.
resource "aws_vpc_endpoint" "athena_gateway_endpoint" {
  vpc_id       = var.vpc_id
  service_name = "com.amazonaws.${data.aws_region.current.region}.athena"
  vpc_endpoint_type = "Gateway"
  route_table_ids = [data.aws_route_table.glue_job_subnet_route_table.id]
}

###########################
###   GLUE CONNECTION   ###
###########################
resource "aws_glue_connection" "glue_connection" {
  name        = "glue_connection"
  description = "Glue connection"
  connection_type = "NETWORK" # Ou JDBC, KAFKA, MONGODB, etc.
  physical_connection_requirements {
    availability_zone = "sa-east-1a"
    # Agora referenciamos o ID do Security Group que acabamos de criar
    security_group_id_list = [aws_security_group.glue_job_security_group.id] 
    subnet_id = var.subnet_id
  }
}


########################
###    GLUE JOB      ###
########################


resource "aws_glue_job" "etl_job" {
  name              = var.glue_job_data_prep
  description       = "Glue ETL job"
  role_arn          = aws_iam_role.glue_job_role.arn
  glue_version      = "5.0"
  max_retries       = 0
  timeout           = 5
  number_of_workers = 2
  worker_type       = "G.1X"
  connections       = [aws_glue_connection.glue_connection.name]
  execution_class   = "STANDARD"

  command {
    script_location = "s3://${aws_s3_bucket.bucket_artefatos.bucket}/app/src/main.py"
    name            = "glueetl"
    python_version  = "3"
  }

  notification_property {
    notify_delay_after = 3 # delay in minutes
  }

  default_arguments = {
    "--job-language"                     = "python"
    "--continuous-log-logGroup"          = "/aws-glue/jobs"
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-continuous-log-filter"     = "true"
    "--enable-metrics"                   = ""
    "--enable-auto-scaling"              = "true"
    "--extra-py-files"                   = "s3://${aws_s3_bucket.bucket_artefatos.bucket}/utils.zip"
  }

  execution_property {
    max_concurrent_runs = 1
  }

  tags = {
    "ManagedBy" = "AWS"
  }
}

# IAM role for Glue jobs
resource "aws_iam_role" "glue_job_role" {
  name = "glue-job-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
      }
    ]
  })
}

# Adicione as políticas de permissão necessárias para a role do Glue Job
# para acessar os buckets S3 e o CloudWatch Logs.
resource "aws_iam_role_policy" "glue_job_s3_access" {
  name = "glue-job-s3-access"
  role = aws_iam_role.glue_job_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject", # Permissão para escrever dados
          "s3:DeleteObject", # Necessário para o modo overwrite
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.bucket_bovespa_raw.arn,
          "${aws_s3_bucket.bucket_bovespa_raw.arn}/*",
          aws_s3_bucket.bucket_bovespa_refined.arn,
          "${aws_s3_bucket.bucket_bovespa_refined.arn}/*",
          aws_s3_bucket.bucket_artefatos.arn,
          "${aws_s3_bucket.bucket_artefatos.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws-glue/jobs:*"
      },
      {
        Effect = "Allow"
        Action = [
          "glue:GetConnection",
          "glue:GetDatabase",
          "glue:GetTable",
          "glue:UpdateTable"
        ]
        # Permissão para acessar o Glue Catalog
        # Ajuste o ARN conforme necessário para o seu Glue Catalog
        Resource = [
            "arn:aws:glue:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:catalog",
            "arn:aws:glue:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:connection/*",
            "arn:aws:glue:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:database/*",
            "arn:aws:glue:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:table/*"
            ]
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DeleteNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeVpcs",
          "ec2:DescribeRouteTables",
          "ec2:DescribeVpcEndpoints",
          "ec2:Describe*",
          "ec2:CreateTags"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
            "athena:StartQueryExecution",
            "athena:GetQueryExecution"
        ]
        Resource = [
            "arn:aws:athena:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:workgroup/primary"
            ]
      }
      ]
  })
}


#############################################
#####   LAMBDA INICIALIZA O GLUE JOB   ######
#############################################

data "archive_file" "lambda_function_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda/lambda_function.py"
  output_path = "${path.module}/../lambda/lambda_function.py"
}

resource "aws_lambda_function" "lambda_inicia_glue_job" {
  function_name = var.lambda_name_inicia_glue_job
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"

  filename         = data.archive_file.lambda_function_zip.output_path
  source_code_hash = data.archive_file.lambda_function_zip.output_base64sha256

  environment {
    variables = {
      GLUE_JOB_NAME = var.glue_job_data_prep
    }
  }

  tags = {
    "ManagedBy" = "AWS"
  }
}

resource "aws_iam_role" "lambda_execution_role" {
  name = "lambda-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}
resource "aws_iam_role_policy" "lambda_s3_access" {
  name = "lambda-s3-access"
  role = aws_iam_role.lambda_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.bucket_bovespa_raw.arn,
          "${aws_s3_bucket.bucket_bovespa_raw.arn}/*",
          aws_s3_bucket.bucket_bovespa_refined.arn,
          "${aws_s3_bucket.bucket_bovespa_refined.arn}/*",
          aws_s3_bucket.bucket_artefatos.arn,
          "${aws_s3_bucket.bucket_artefatos.arn}/*"
        ]
      }
    ]
  })
}
resource "aws_iam_role_policy" "lambda_policy" {
  name = "lambda-glue-trigger-policy"
  role = aws_iam_role.lambda_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.lambda_name_inicia_glue_job}:*"
      },
      {
        Effect = "Allow"
        Action = "glue:StartJobRun"
        Resource = aws_glue_job.etl_job.arn
      },
      {
        Effect = "Allow",
        Action = [
            "glue:CreatePartition",
            "glue:GetTable",
            "glue:GetDatabase",
            "glue:GetPartitions"
        ],
        Resource = "*"
      }
    ]
  })
}

#############################################
#####   S3 Notification para Lambda   #######
#############################################

# Permissão para o S3 invocar a função Lambda
resource "aws_lambda_permission" "allow_s3_to_call_lambda" {
  statement_id  = "AllowS3InvokeLambda"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_inicia_glue_job.function_name
  principal     = "s3.amazonaws.com"
  # O source_arn deve ser o ARN do bucket que irá disparar a notificação
  source_arn    = aws_s3_bucket.bucket_bovespa_raw.arn
}

# Configuração de notificação do bucket S3
resource "aws_s3_bucket_notification" "bovespa_raw_to_lambda" {
  bucket = aws_s3_bucket.bucket_bovespa_raw.id

  # Configuração para eventos de criação de objeto (Put, Post, Copy, MultipartUpload)
  lambda_function {
    lambda_function_arn = aws_lambda_function.lambda_inicia_glue_job.arn
    events              = ["s3:ObjectCreated:*"] # Dispara para qualquer criação de objeto
    # Opcional: prefix e/ou suffix para filtrar eventos por caminho/extensão
    # filter_prefix       = "raw_data/"
    # filter_suffix       = ".csv"
  }

  # Depende da permissão para garantir que a permissão seja criada antes da notificação
  depends_on = [aws_lambda_permission.allow_s3_to_call_lambda]
}

#############################################
#####   LAMBDA SCRAPPER SALVA PARQUET  ######
#############################################

module "lambda_functions_scrapper" {
  source = "terraform-aws-modules/lambda/aws"
  
  function_name = var.lambda_name_scrap_b3
  description   = var.lambda_name_scrap_b3
  handler       = "lambda_functions_scrapper.lambda_handler"
  runtime       = "python3.13"

  source_path = "${path.module}/../lambda/lambda_functions_scrapper.py"
  memory_size = 512
  timeout     = 60
  create_role = false
  lambda_role    = aws_iam_role.lambda_execution_role.arn
  environment_variables = {
    S3_BUCKET_NAME     = var.bucket_name_bovespa_bruto
    GLUE_DATABASE_NAME = aws_glue_catalog_database.raw_database.name
    GLUE_TABLE_NAME    = var.table_bovespa_raw
  }

  layers = [var.lambda_layer_scrapper_artefatos_arn]

  tags = {
    Name = "my-lambda1"
  }
}

############################################################
#### Agendador (EventBridge Rule) para a função Lambda  ####
############################################################
resource "aws_cloudwatch_event_rule" "ibov_scraper_schedule" {
  name                = "ibov-scraper-daily-schedule"
  description         = "Agenda a execução da função Lambda de scraping do IBovespa diariamente."
  schedule_expression = "cron(0 12 * * ? *)" # Exemplo: executa a cada 1 dia. Use "cron(0 12 * * ? *)" para 12:00 UTC diariamente.
  state          = "ENABLED"
  tags = {
    Name = "ibov-scraper-schedule"
  }
}

# Permissão para o EventBridge invocar a função Lambda
resource "aws_lambda_permission" "allow_cloudwatch_to_call_ibov_scraper" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda_functions_scrapper.lambda_function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.ibov_scraper_schedule.arn
}

# Define o alvo do agendador (a função Lambda)
resource "aws_cloudwatch_event_target" "ibov_scraper_target" {
  rule      = aws_cloudwatch_event_rule.ibov_scraper_schedule.name
  target_id = "ibov-scraper-lambda-target"
  arn       = module.lambda_functions_scrapper.lambda_function_arn
}

####################################
####### GLUE CATALOG DATABASE ######
####################################
resource "aws_glue_catalog_database" "raw_database" {
  name       = "raw_database_name"
  catalog_id = data.aws_caller_identity.current.account_id
  # ...
}

resource "aws_glue_catalog_database" "refined_database" {
  name       = "refined_database_name"
  catalog_id = data.aws_caller_identity.current.account_id
  # ...
}
module "raw_layer_tables" {
  source = "./modules/table/raw" # Aponta para o diretório do módulo da camada RAW

  database_name              = aws_glue_catalog_database.raw_database.name # Passa o nome do DB RAW
  environment                = var.environment
  bucket_name_bovespa_bruto  = var.bucket_name_bovespa_bruto
  table_bovespa_raw          = var.table_bovespa_raw
  
  depends_on = [aws_glue_catalog_database.raw_database, aws_s3_bucket.bucket_bovespa_raw]
}