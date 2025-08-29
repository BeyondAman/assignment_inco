resource "aws_s3_bucket" "state" {
  bucket = var.bucket_name
  tags = merge(var.tags, {
    purpose     = "terraform-state"
    environment = var.env
    project     = "beyond_inco"
  })
  lifecycle { prevent_destroy = true }
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.state.id
  rule { object_ownership = "BucketOwnerEnforced" }
}

resource "aws_kms_key" "state" {
  count                   = var.enable_kms ? 1 : 0
  description             = "CMK for Terraform state bucket (${var.bucket_name})"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  tags                    = var.tags
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.enable_kms ? "aws:kms" : "AES256"
      kms_master_key_id = var.enable_kms ? aws_kms_key.state[0].arn : null
    }
    bucket_key_enabled = var.enable_kms ? true : null
  }
}

data "aws_iam_policy_document" "policy" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    principals { type = "*"; identifiers = ["*"] }
    resources = [aws_s3_bucket.state.arn, "${aws_s3_bucket.state.arn}/*"]
    condition { test = "Bool" variable = "aws:SecureTransport" values = ["false"] }
  }

  statement {
    sid     = "DenyUnencryptedUploads"
    effect  = "Deny"
    actions = ["s3:PutObject"]
    principals { type = "*"; identifiers = ["*"] }
    resources = ["${aws_s3_bucket.state.arn}/*"]
    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption"
      values   = [var.enable_kms ? "aws:kms" : "AES256"]
    }
  }

  dynamic "statement" {
    for_each = length(var.allowed_role_arns) > 0 ? [1] : []
    content {
      sid     = "AllowListBucketForRoles"
      effect  = "Allow"
      principals { type = "AWS"; identifiers = var.allowed_role_arns }
      actions   = ["s3:ListBucket"]
      resources = [aws_s3_bucket.state.arn]
    }
  }

  dynamic "statement" {
    for_each = length(var.allowed_role_arns) > 0 ? [1] : []
    content {
      sid     = "AllowRWOnStateAndLock"
      effect  = "Allow"
      principals { type = "AWS"; identifiers = var.allowed_role_arns }
      actions   = ["s3:GetObject","s3:PutObject","s3:DeleteObject"]
      resources = [
        "${aws_s3_bucket.state.arn}/${var.state_key}",
        "${aws_s3_bucket.state.arn}/${var.state_key}.tflock"
      ]
    }
  }
}

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.state.id
  policy = data.aws_iam_policy_document.policy.json
}
