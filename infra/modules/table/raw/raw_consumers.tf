# modules/raw_layer/raw_customers.tf

module "raw_customer_data" {
  source = "../glue_parquet_table" # Caminho relativo para o módulo glue_table

  table_name    = "customers_raw"
  database_name = var.database_name
  s3_location   = "s3://${var.s3_data_lake_bucket_name}/raw/customers/"

  columns = [
    { name = "customer_id", type = "string" },
    { name = "name", type = "string" },
    { name = "email", type = "string" },
    { name = "registration_date", type = "string" },
  ]

  tags = {
    Layer       = "Raw"
    Source      = "CRM"
    Environment = var.environment
  }
}
