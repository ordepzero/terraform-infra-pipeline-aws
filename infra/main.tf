########################
### RECURSOS S3 (MANTIDOS COMO ESTÃO) ###
########################
resource "aws_s3_bucket" "bucket_bovespa_raw" {
  bucket = var.bucket_name_bovespa_raw
}

resource "aws_s3_bucket" "bucket_bovespa_refined" {
  bucket = var.bucket_name_bovespa_refined
}


########################
### CRIANDO ROLES IAM DEDICADAS ###
########################

# Role para a Step Functions executar suas tarefas (ex: logs, Lambda, etc.)
resource "aws_iam_role" "sfn_execution_role" {
  name = "sfn-execution-role-${var.enviroment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          # Este serviço é quem assume a role para executar a Step Functions
          Service = "states.${data.aws_region.current.name}.amazonaws.com" # Use data.aws_region para ser dinâmico
        }
      }
    ]
  })
}

# Política para permitir que a Step Functions escreva logs no CloudWatch
resource "aws_iam_policy" "sfn_logs_policy" {
  name        = "sfn-logs-policy-${var.enviroment}"
  description = "Allows Step Functions to write logs to CloudWatch"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams" # Pode ser útil para depuração
        ],
        Resource = "arn:aws:logs:*:*:log-group:/aws/vendedlogs/states/generic-stepfunction-${var.enviroment}:*" # Ajustar o caminho do log group
      }
    ]
  })
}

# Anexar a política de logs à role de execução da Step Functions
resource "aws_iam_role_policy_attachment" "sfn_logs_attachment" {
  role       = aws_iam_role.sfn_execution_role.name
  policy_arn = aws_iam_policy.sfn_logs_policy.arn
}

# Opcional: Se sua Step Functions chamar outros serviços (Lambda, DynamoDB, etc.), adicione políticas aqui.
# Exemplo:
# resource "aws_iam_policy_attachment" "sfn_lambda_invoke_attachment" {
#   role       = aws_iam_role.sfn_execution_role.name
#   policy_arn = "arn:aws:iam::aws:policy/AWSLambda_FullAccess" # Ou uma política mais restritiva
# }


# Role para o EventBridge invocar a Step Functions
resource "aws_iam_role" "eventbridge_invoke_sfn_role" {
  name = "eventbridge-invoke-sfn-role-${var.enviroment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "events.amazonaws.com" # Este serviço é quem assume a role para disparar a SFN
        }
      }
    ]
  })
}

# Política para permitir que o EventBridge inicie a Step Functions
resource "aws_iam_policy" "eventbridge_sfn_start_execution_policy" {
  name        = "eventbridge-sfn-start-execution-policy-${var.enviroment}"
  description = "Allows EventBridge to start Step Functions executions"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = "states:StartExecution",
        # Permissão para iniciar *esta* Step Functions específica
        Resource = aws_sfn_state_machine.generic_step_function.arn
      }
    ]
  })
}

# Anexar a política de invocação à role do EventBridge
resource "aws_iam_role_policy_attachment" "eventbridge_sfn_attachment" {
  role       = aws_iam_role.eventbridge_invoke_sfn_role.name
  policy_arn = aws_iam_policy.eventbridge_sfn_start_execution_policy.arn
}

# Remova ou renomeie as roles/usuários/grupos/políticas "generic_" se elas não forem mais necessárias
# ou se quiser ter uma convenção mais clara.
# Por exemplo, "aws_iam_user.generic_user", "aws_iam_role.generic_role", etc.
# Parecem ser genéricas e não diretamente relacionadas ao EventBridge/Step Functions.

################################################
##### STEPFUNCTION (CORRIGIDA ROLE_ARN) #######
################################################
resource "aws_sfn_state_machine" "generic_step_function" {
  name     = "generic-stepfunction-${var.enviroment}"
  # Use a role dedicada para execução da Step Functions
  role_arn = aws_iam_role.sfn_execution_role.arn
  type     = "STANDARD"

  definition = jsonencode({
    Comment = "A simple state machine that takes input and passes it through."
    StartAt = "PassState"
    States = {
      PassState = {
        Type = "Pass"
        End  = true
      }
    }
  })
}

################################################
##### EVENTBRIDGE (CORRIGIDA REGRA E ROLE) #####
################################################

resource "aws_cloudwatch_event_rule" "generic_trigger_step_function_rule" {
  name                = "event-bridge-${var.enviroment}"
  description         = "Iniciar generic stepfunction a cada 5 minutos"
  # Removido o 'event_pattern' para evitar conflito. Apenas o schedule_expression será usado.
  schedule_expression = "rate(5 minutes)"
}

resource "aws_cloudwatch_event_target" "invoke_step_function_target" {
  rule      = aws_cloudwatch_event_rule.generic_trigger_step_function_rule.name
  arn       = aws_sfn_state_machine.generic_step_function.arn

  # Definindo o input JSON.
  # Use '<aws.events.event.time>' para pegar o timestamp do evento EventBridge
  # Se precisar do ID da execução da Step Functions (que só existe depois de iniciar),
  # você pode acessar em `$$.Execution.Id` *dentro* da Step Functions.
  input = jsonencode({
    "eventName" : "ScheduledEvent",
    "timestamp" : "<aws.events.event.time>", # EventBridge context variable for event time
    "data"      : {
      "message": "Este é um input de exemplo do EventBridge para a Step Functions!",
      "environment": var.enviroment, # Use a variável do Terraform aqui
      "recordCount": 123
    }
  })

  # Use a role dedicada para o EventBridge invocar a Step Functions
  role_arn = aws_iam_role.eventbridge_invoke_sfn_role.arn
}

# Data source para obter a região atual, útil para o service principal da SFN
data "aws_region" "current" {}