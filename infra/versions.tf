terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0" # Garante o uso de uma versão recente do provedor AWS
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.2.0" # Necessário para o recurso 'data "archive_file"'
    }
  }

  required_version = ">= 1.3" # Recomenda uma versão mínima do Terraform
}

# Data source para obter a região atual
data "aws_region" "current" {}


