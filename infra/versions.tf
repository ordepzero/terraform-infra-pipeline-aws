terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      # Use uma versão mais recente e estável da série 6.x.x
      # Recomendo verificar em registry.terraform.io/providers/hashicorp/aws
      # qual é a versão mais recente e estável (ex: 6.20.0, 6.25.0 etc.)
      version = "~> 6.20.0" # Exemplo: Aceita qualquer 6.x.x >= 6.20.0 e < 7.0.0
    }
  }
}
