terraform { backend "s3" {} }

module "static_content" {
  source              = "./modules/static_content_stack"
  env                 = var.env
  region              = var.region
  tags                = var.tags
  acm_certificate_arn = var.acm_certificate_arn
  waf_web_acl_arn     = var.waf_web_acl_arn
}
