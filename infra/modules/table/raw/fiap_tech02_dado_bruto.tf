# modules/raw_layer/raw_customers.tf

module "table_bovespa_raw" {
  source = "../glue_parquet_table" # Caminho relativo para o módulo glue_table

  table_name    = var.table_bovespa_raw
  database_name = "${var.environment}_${var.database_name}"
  s3_location   = "s3://${var.bucket_name_bovespa_bruto}/${var.table_bovespa_raw}"

  columns = [
    { name = "segment", type = "string" },
    { name = "cod", type = "string" },
    { name = "asset", type = "string" },
    { name = "type", type = "string" },
    { name = "part", type = "string" },
    { name = "partAcum", type = "string" },
    { name = "theoricalQty", type = "string" }
  ]

  partition_keys = [
    { name = "ano", type = "string" },
    { name = "mes", type = "string" },
    { name = "dia", type = "string" },
  ]
  tags = {
    Layer       = "Raw"
    Source      = "Bovespa"
    Environment = var.environment
  }
}
