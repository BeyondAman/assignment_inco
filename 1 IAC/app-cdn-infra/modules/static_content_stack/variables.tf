variable "env"                 { type = string }

variable "region"              { type = string }

variable "tags"                { 
  type = map(string)
  default = {}
}

variable "acm_certificate_arn" { 
  type = string
  default = ""
}

variable "waf_web_acl_arn"     {
  type = string
  default = ""
}

variable "bucket_name_prefix"  {
  type = string
  description = "The prefix for the S3 bucket names."
}