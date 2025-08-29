terraform {
  backend "s3" {}
}

module "state_bucket" {
  source            = "./modules/s3_state_bucket"
  bucket_name       = var.bucket_name
  env               = var.env
  region            = var.region
  enable_kms        = var.enable_kms
  allowed_role_arns = var.allowed_role_arns
  state_key         = var.state_key
  tags              = var.tags
}
