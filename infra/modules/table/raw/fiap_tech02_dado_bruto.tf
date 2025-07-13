# modules/raw_layer/raw_customers.tf

module "table_bovespa_raw" {
  source = "../glue_parquet_table" # Caminho relativo para o módulo glue_table

  table_name    = var.table_bovespa_raw
  database_name = var.database_name
  s3_location   = "s3://${var.bucket_name_bovespa_bruto}/${var.table_bovespa_raw}"

  columns = [
    { name = "codigo_bovespa", type = "string" },
    { name = "nome_acao", type = "string" },
    { name = "nome_tipo_acao", type = "string" },
    { name = "quantidade_teorica", type = "string" },
    { name = "percentual_participacao_acao", type = "string" },
    { name = "data_pregao", type = "date" }
  ]

  partition_keys = [
    { name = "ano", type = "string" },
    { name = "mes", type = "string" },
    { name = "dia", type = "string" },
  ]
  tags = {
    Layer       = "Raw"
    Source      = "CRM"
    Environment = var.environment
  }
}
