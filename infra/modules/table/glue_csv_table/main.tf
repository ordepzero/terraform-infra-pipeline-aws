# modules/glue_table/main.tf

resource "aws_glue_catalog_table" "this" {
  name          = var.table_name
  database_name = var.database_name
  owner         = "hadoop" # Exemplo de owner
  retention     = 0 # Exemplo de retenção

  storage_descriptor {
    location      = var.s3_location
    input_format  = "org.apache.hadoop.mapred.TextInputFormat" # Formato de entrada padrão
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat" # Formato de saída padrão
    compressed    = false # Se os dados estão compactados

    ser_de_info {
      name                  = "OpenCSVSerDe" # Exemplo para CSV
      serialization_library = "org.apache.hadoop.hive.serde2.OpenCSVSerde"
      parameters = {
        "separatorChar" = ","
        "quoteChar"     = "\""
        "escapeChar"    = "\\"
      }
    }

    dynamic "columns" {
      for_each = var.columns
      content {
        name    = columns.value.name
        type    = columns.value.type
        comment = lookup(columns.value, "comment", null)
      }
    }
  }

  dynamic "partition_keys" {
    for_each = var.partition_keys
    content {
      name    = partition_keys.value.name
      type    = partition_keys.value.type
      comment = lookup(partition_keys.value, "comment", null)
    }
  }

  parameters = {
    "classification" = "csv" # Exemplo de classificação
    "skip.header.line.count" = "1" # Exemplo: pular cabeçalho
  }

  lifecycle {
    ignore_changes = [
      parameters["CrawlerSchemaDeserializerVersion"], # Ignorar mudanças de crawlers
      parameters["averageRecordSize"],
      parameters["recordCount"],
      parameters["sizeKey"],
      parameters["compressionType"],
      parameters["columns"],
      parameters["numRows"],
      storage_descriptor[0].columns,
    ]
  }
}