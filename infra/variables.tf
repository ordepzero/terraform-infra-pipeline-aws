variable "enviroment" {
  description = "The environment for which the infrastructure is being provisioned. It can be 'dev', 'hom', or 'prod'."
  type        = string
}
variable "bucket_name_bovespa_raw" {
  description = "The name of the S3 bucket to create bucket_name_bovespa_raw."
  type        = string
}

variable "bucket_name_bovespa_refined" {
  description = "The name of the S3 bucket to create bucket_name_bovespa_refined."
  type        = string
}