# Create bucket policies after CloudFront distribution exists
resource "aws_s3_bucket_policy" "auth_policy" {
  bucket = module.bucket_auth.bucket_name
  policy = data.aws_iam_policy_document.auth_policy.json
  
  depends_on = [module.cdn]
}

resource "aws_s3_bucket_policy" "info_policy" {
  bucket = module.bucket_info.bucket_name  
  policy = data.aws_iam_policy_document.info_policy.json
  
  depends_on = [module.cdn]
}

resource "aws_s3_bucket_policy" "customers_policy" {
  bucket = module.bucket_customers.bucket_name
  policy = data.aws_iam_policy_document.customers_policy.json
  
  depends_on = [module.cdn]
}
