locals {
  common_tags = merge(var.tags, { project = "beyond_inco", environment = var.env })
}

module "bucket_auth" {
  source      = "../s3_bucket_secure"
  name        = "storage-bucket1-${var.env}-beyondinco"
  region      = var.region
  enable_kms  = true
  tags        = merge(local.common_tags, { purpose = "auth" })
}

module "bucket_info" {
  source      = "../s3_bucket_secure"
  name        = "${var.bucket_name_prefix}-info-${var.env}"
  region      = var.region
  enable_kms  = true
  tags        = merge(local.common_tags, { purpose = "info" })
}

module "bucket_customers" {
  source      = "../s3_bucket_secure"
  name        = "${var.bucket_name_prefix}-customers-${var.env}"
  region      = var.region
  enable_kms  = true
  tags        = merge(local.common_tags, { purpose = "customers" })
}

module "cdn" {
  source  = "../cloudfront_with_oac"
  env     = var.env
  region  = var.region
  tags    = local.common_tags

  origins = {
    "origin-auth-${var.env}" = {
      domain_name   = module.bucket_auth.bucket_name + ".s3.amazonaws.com"
      origin_path   = ""
      s3_bucket_arn = module.bucket_auth.bucket_arn
    }
    "origin-info-${var.env}" = {
      domain_name   = module.bucket_info.bucket_name + ".s3.amazonaws.com"
      origin_path   = ""
      s3_bucket_arn = module.bucket_info.bucket_arn
    }
    "origin-customers-${var.env}" = {
      domain_name   = module.bucket_customers.bucket_name + ".s3.amazonaws.com"
      origin_path   = ""
      s3_bucket_arn = module.bucket_customers.bucket_arn
    }
  }

  path_behaviors = [
    { path_pattern = "/auth/*",      target_origin_id = "origin-auth-${var.env}" },
    { path_pattern = "/info/*",      target_origin_id = "origin-info-${var.env}" },
    { path_pattern = "/customers/*", target_origin_id = "origin-customers-${var.env}" }
  ]

  acm_certificate_arn = var.acm_certificate_arn
  waf_web_acl_arn     = var.waf_web_acl_arn
}

data "aws_iam_policy_document" "auth_policy" {
  statement {
    sid     = "AllowCloudFrontReadViaOAC"
    effect  = "Allow"
    actions = ["s3:GetObject"]
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    resources = ["${module.bucket_auth.bucket_arn}/*"]
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [module.cdn.distribution_arn]
    }
  }
}
data "aws_iam_policy_document" "info_policy" {
  statement {
    sid     = "AllowCloudFrontReadViaOAC"
    effect  = "Allow"
    actions = ["s3:GetObject"]
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    resources = ["${module.bucket_info.bucket_arn}/*"]
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [module.cdn.distribution_arn]
    }
  }
}
data "aws_iam_policy_document" "customers_policy" {
  statement {
    sid     = "AllowCloudFrontReadViaOAC"
    effect  = "Allow"
    actions = ["s3:GetObject"]
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    resources = ["${module.bucket_customers.bucket_arn}/*"]
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [module.cdn.distribution_arn]
    }
  }
}

output "auth_bucket"      { value = module.bucket_auth.bucket_name }
output "info_bucket"      { value = module.bucket_info.bucket_name }
output "customers_bucket" { value = module.bucket_customers.bucket_name }
output "distribution_id"  { value = module.cdn.aws_cloudfront_distribution_this_id }
