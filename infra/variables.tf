variable "environment" {
  description = "The environment for which the infrastructure is being provisioned. It can be 'dev', 'hom', or 'prod'."
  type        = string
}
variable "bucket_name_bovespa_bruto" {
  description = "The name of the S3 bucket to create bucket_name_bovespa_raw."
  type        = string
}

variable "bucket_name_bovespa_refinado" {
  description = "The name of the S3 bucket to create bucket_name_bovespa_refined."
  type        = string
}

variable "database_bovespa_raw" {
  description = "O nome do banco de dados Glue para os dados brutos da Bovespa."
  type        = string
}

variable "database_bovespa_refined" {
  description = "O nome do banco de dados Glue para os dados refinados da Bovespa."
  type        = string
}

variable "table_bovespa_raw" {
  description = "O nome da tabela Glue para os dados brutos da Bovespa."
  type        = string
}

variable "table_bovespa_refined" {
  description = "O nome da tabela Glue para os dados refinados da Bovespa."
  type        = string
}

variable "bucket_name_artefatos" {
  description = "The name of the S3 bucket armazenar os scripts."
  type        = string
}


variable "glue_job_data_prep" {
  description = "The name of the Glue job data preparation."
  type        = string
}

variable "lambda_name_scrap_b3" {
  description = "The name of the Lambda function that scrapes B3 data."
  type        = string
}

variable "lambda_name_inicia_glue_job" {
  description = "The name of the Lambda function that starts the Glue job."
  type        = string
}

variable "lambda_layer_scrapper_artefatos_arn" {
  description = "The name of the Lambda layer that contains the scrapper artifacts."
  type        = string
  
}

variable "vpc_id" {
  description = "The ID of the VPC where the Lambda function will be deployed."
  type        = string
}

variable "subnet_id" {
  description = "The subnet ID where the Lambda function will be deployed."
  type        = string
}