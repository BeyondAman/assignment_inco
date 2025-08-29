variable "name"       { type = string }
variable "region"     { type = string }
variable "enable_kms" { 
  type = bool 
  default = true 
  }
variable "tags"       { type = map(string) default = {} }
variable "policy_json" {
  type = string
  default = ""
  description = "Optional S3 bucket policy in JSON format."
}