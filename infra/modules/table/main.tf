resource "aws_glue_catalog_database" "example" {
  name = "MyCatalogDatabase2"

  create_table_default_permission {
    permissions = ["SELECT"]

    principal {
      data_lake_principal_identifier = "IAM_ALLOWED_PRINCIPALS"
    }
  }
}