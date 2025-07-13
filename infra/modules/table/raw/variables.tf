variable "bucket_raw" {
    type        = string
    default     = ""
}

variable "database_raw" {
    type        = string
    default     = ""
}

variable "table_bovespa_raw" {
    type        = string
    default     = ""
}

# modules/raw_layer/variables.tf

variable "database_name" {
  description = "O nome do banco de dados Glue para as tabelas RAW."
  type        = string
}

variable "s3_data_lake_bucket_name" {
  description = "O nome do bucket S3 do data lake."
  type        = string
}

variable "bucket_name_bovespa_bruto" {
  description = "O nome do bucket S3 para os dados brutos da Bovespa."
  type        = string
}

variable "environment" {
  description = "Ambiente de implantação."
  type        = string
}
