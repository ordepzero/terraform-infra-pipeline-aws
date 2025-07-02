terraform {
  backend "s3" {
    bucket         = "ordepzero-sa-east-1-terraform-statefile"
    region         = "sa-east-1"
    dynamodb_table = "ordepzero-sa-east-1-terraform-lock"
    encrypt        = true
  }
}
provider "aws" {
  region = "sa-east-1"
}
