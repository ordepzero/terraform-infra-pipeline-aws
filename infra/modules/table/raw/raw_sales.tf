# modules/raw_layer/raw_sales.tf

module "raw_sales_data" {
  source = "../glue_table" # Caminho relativo para o módulo glue_table

  table_name    = "sales_raw"
  database_name = var.database_name
  s3_location   = "s3://${var.s3_data_lake_bucket_name}/raw/sales/"

  columns = [
    { name = "transaction_id", type = "string" },
    { name = "product_id", type = "string" },
    { name = "sale_date", type = "string" },
    { name = "amount", type = "string" }, # Armazenado como string na RAW para flexibilidade
  ]

  partition_keys = [
    { name = "year", type = "string" },
    { name = "month", type = "string" },
    { name = "day", type = "string" },
  ]

  tags = {
    Layer       = "Raw"
    Source      = "CRM"
    Environment = var.environment
  }
}
