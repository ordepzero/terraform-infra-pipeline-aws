# modules/raw_layer/raw_customers.tf

module "table_bovespa_refinado" {
  source = "../glue_parquet_table" # Caminho relativo para o módulo glue_table

  table_name    = var.table_bovespa_refinado
  database_name = var.database_name
  s3_location   = "s3://${var.bucket_name_bovespa_refinado}/${var.table_bovespa_refinado}"

  columns = [
    { name = "segmento", type = "string" },
    { name = "codigo_bovespa", type = "string" },
    { name = "nome_acao", type = "string" },
    { name = "nome_tipo_acao", type = "string" },
    { name = "percentual_participacao_acao", type = "decimal(18,3)" },
    { name = "percentual_participacao_acumulada", type = "decimal(18,3)" },
    { name = "quantidade_teorica", type = "decimal(18,2)" }
  ]

  partition_keys = [
    { name = "ano", type = "string" },
    { name = "mes", type = "string" },
    { name = "dia", type = "string" },
    { name = "data_pregao", type = "date" }
  ]
  tags = {
    Layer       = "Refined"
    Source      = "Bovespa"
    Environment = var.environment
  }
}
