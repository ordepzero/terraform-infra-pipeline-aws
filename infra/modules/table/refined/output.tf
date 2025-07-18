# modules/refined_layer/outputs.tf

output "refined_tables_names" {
  description = "Nomes de todas as tabelas refinadas criadas."
  value = {
    bovespa_refinado = module.table_bovespa_refined.table_name
    # Adicione aqui os nomes de outras tabelas REFINADAS conforme forem criadas
  }
}

output "refined_tables_arns" {
  description = "ARNs de todas as tabelas refinadas criadas."
  value = {
    bovespa_refinado_arn = module.table_bovespa_refined.table_arn
    # Adicione aqui os ARNs de outras tabelas REFINADAS conforme forem criadas
  }
}
