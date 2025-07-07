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
###   ARTEFATOS PYTHON PARA O GLUE JOB       ###
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
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws-glue/jobs:*"
      }
    ]
  })
}

resource "aws_glue_connection" "glue_connection" {
  name        = "glue_connection"
  description = "Glue connection"
  connection_type = "NETWORK" # Ou JDBC, KAFKA, MONGODB, etc.
  # Adicione os parâmetros de conexão necessários aqui, se aplicável.
  # match_criteria = ["example"]
  physical_connection_requirements {
    availability_zone = "sa-east-1a"
    security_group_id_list = ["sg-0c77e0a62cf6d76d9"]
    subnet_id = "subnet-095b4b564407caf39"
  }
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
      GLUE_JOB_NAME = aws_glue_job.etl_job.name
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
