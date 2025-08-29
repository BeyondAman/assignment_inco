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
  name        = "storage-bucket2-${var.env}-beyondinco"
  region      = var.region
  enable_kms  = true
  tags        = merge(local.common_tags, { purpose = "info" })
}

module "bucket_customers" {
  source      = "../s3_bucket_secure"
  name        = "storage-bucket3-${var.env}-beyondinco"
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

output "auth_bucket"      { value = module.bucket_auth.bucket_name }
output "info_bucket"      { value = module.bucket_info.bucket_name }
output "customers_bucket" { value = module.bucket_customers.bucket_name }
output "distribution_id"  { value = module.cdn.aws_cloudfront_distribution_this_id }
