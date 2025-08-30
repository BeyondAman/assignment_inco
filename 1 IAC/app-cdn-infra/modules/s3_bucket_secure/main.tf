resource "aws_s3_bucket" "this" {
  bucket = var.name
  tags   = var.tags
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket                  = aws_s3_bucket.this.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.id
  rule { object_ownership = "BucketOwnerEnforced" }
}

resource "aws_kms_key" "cmk" {
  count                   = var.enable_kms ? 1 : 0
  description             = "CMK for ${var.name}"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  tags                    = var.tags
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.enable_kms ? "aws:kms" : "AES256"
      kms_master_key_id = var.enable_kms ? aws_kms_key.cmk[0].arn : null
    }
    bucket_key_enabled = var.enable_kms ? true : null
  }
}

output "bucket_name" { value = aws_s3_bucket.this.bucket }
output "bucket_arn"  { value = aws_s3_bucket.this.arn }
output "kms_key_arn" { value = try(aws_kms_key.cmk[0].arn, null) }
output "bucket_regional_domain_name" {
  description = "Regional domain name for the bucket (e.g. bucket.s3.us-east-1.amazonaws.com)"
  value       = aws_s3_bucket.this.bucket_regional_domain_name
}