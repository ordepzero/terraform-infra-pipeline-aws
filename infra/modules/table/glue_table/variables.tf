# modules/glue_table/variables.tf

variable "table_name" {
  description = "O nome da tabela Glue."
  type        = string
}

variable "database_name" {
  description = "O nome do banco de dados Glue onde a tabela será criada."
  type        = string
}

variable "s3_location" {
  description = "O caminho S3 onde os dados da tabela estão localizados."
  type        = string
}

variable "columns" {
  description = "Uma lista de mapas descrevendo as colunas da tabela."
  type = list(object({
    name    = string
    type    = string
    comment = optional(string)
  }))
}

variable "partition_keys" {
  description = "Uma lista de mapas descrevendo as chaves de partição da tabela."
  type = list(object({
    name    = string
    type    = string
    comment = optional(string)
  }))
  default = [] # Por padrão, não há chaves de partição
}

variable "tags" {
  description = "Um mapa de tags para aplicar à tabela Glue."
  type        = map(string)
  default     = {}
}
