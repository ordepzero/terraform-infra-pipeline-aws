# modules/glue_table/main.tf

resource "aws_glue_catalog_table" "this" {
  name          = var.table_name
  database_name = var.database_name

  storage_descriptor {
    location      = var.s3_location
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"
    compressed    = false # Se os dados estão compactados

    ser_de_info {
        serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
        parameters = {
            "serialization.format" = "1"
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
    EXTERNAL = "TRUE"
    "parquet.compression" = "SNAPPY"
    classification = "parquet"
    useGlueParquetWriter = true
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