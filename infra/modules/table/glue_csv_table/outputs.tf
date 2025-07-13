# modules/glue_table/outputs.tf

output "table_arn" {
  description = "O ARN da tabela Glue criada."
  value       = aws_glue_catalog_table.this.arn
}

output "table_name" {
  description = "O nome da tabela Glue criada."
  value       = aws_glue_catalog_table.this.name
}
