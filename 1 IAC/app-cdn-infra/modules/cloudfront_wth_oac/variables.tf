variable "env"                 { type = string }
variable "region"              { type = string }
variable "origins"             {
  description = "Map of origin_id => { domain_name, origin_path (optional), s3_bucket_arn }"
  type = map(object({
    domain_name  = string
    origin_path  = optional(string, "")
    s3_bucket_arn = string
  }))
}
variable "path_behaviors" {
  description = "Ordered list of { path_pattern, target_origin_id }"
  type = list(object({
    path_pattern     = string
    target_origin_id = string
  }))
}
variable "acm_certificate_arn" { type = string  default = "" }
variable "waf_web_acl_arn"     { type = string  default = "" }
variable "tags"                { type = map(string) default = {} }
