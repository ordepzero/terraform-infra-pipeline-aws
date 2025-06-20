resource "aws_s3_bucket" "bucket_bovespa_raw" {
  bucket = var.bucket_name_bovespa_raw
}

resource "aws_s3_bucket" "bucket_bovespa_refined" {
  bucket = var.bucket_name_bovespa_refined
}