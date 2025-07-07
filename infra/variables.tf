variable "enviroment" {
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