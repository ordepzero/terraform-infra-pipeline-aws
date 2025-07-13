# modules/raw_layer/raw_customers.tf

module "raw_customer_data" {
  source = "../glue_parquet_table" # Caminho relativo para o módulo glue_table

  table_name    = "customers_raw"
  database_name = var.database_name
  s3_location   = "s3://${var.s3_data_lake_bucket_name}/raw/customers/"

  columns = [
    { name = "codigo_bovespa", type = "string" },
    { name = "nome_acao", type = "string" },
    { name = "nome_tipo_acao", type = "string" },
    { name = "quantidade_teorica", type = "string" },
    { name = "percentual_participacao_acao", type = "string" },
    { name = "data_pregao", type = "date" }
  ]

  partition_keys = [
    { name = "data_processamento", type = "date" },
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
