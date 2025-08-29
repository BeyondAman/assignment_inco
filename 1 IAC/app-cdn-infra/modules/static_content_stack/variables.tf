variable "env"                 { type = string }
variable "region"              { type = string }
variable "tags"                { type = map(string) default = {} }
variable "acm_certificate_arn" { type = string default = "" }
variable "waf_web_acl_arn"     { type = string default = "" }
