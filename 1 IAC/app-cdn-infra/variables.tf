variable "env"     { type = string }
variable "region"  { type = string }
variable "tags"    { type = map(string) default = {} }

# TLS certificate (ACM in us-east-1 for CloudFront if using custom domains)
variable "acm_certificate_arn" { type = string default = "" }

# Optional WAF web ACL ARN
variable "waf_web_acl_arn" { type = string default = "" }
