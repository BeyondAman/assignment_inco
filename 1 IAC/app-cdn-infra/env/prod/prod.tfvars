env    = "prod"
region = "us-east-1"
tags = { owner = "platform", project = "beyond-inco", env = "prod" }
acm_certificate_arn = "arn:aws:acm:us-east-1:${data.aws_caller_identity.current.account_id}:certificate/<certificate-id>"
waf_web_acl_arn     = ""