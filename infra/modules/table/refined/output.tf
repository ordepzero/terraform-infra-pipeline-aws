# modules/raw_layer/outputs.tf

output "refined_tables_names" {
  description = "Nomes de todas as tabelas RAW criadas."
  value = {
    bovespa_raw = module.table_bovespa_refined.table_name
    # Adicione aqui os nomes de outras tabelas RAW conforme forem criadas
  }
}

output "refined_tables_arns" {
  description = "ARNs de todas as tabelas RAW criadas."
  value = {
    sales_raw = module.table_bovespa_refined.table_arn
    # Adicione aqui os ARNs de outras tabelas RAW conforme forem criadas
  }
}
