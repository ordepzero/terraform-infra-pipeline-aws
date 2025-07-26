variable "database_name" {
  description = "O nome do banco de dados Glue para as tabelas RAW."
  type        = string
}

variable "table_bovespa_refined" {
  description = "O nome da tabela Glue para os dados refinado da Bovespa."
  type        = string
}

variable "bucket_name_bovespa_refinado" {
  description = "O nome do bucket S3 que armazena os dados refinados da Bovespa."
  type        = string
}

variable "environment" {
  description = "Ambiente de implantação."
  type        = string
}
