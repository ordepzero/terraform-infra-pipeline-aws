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