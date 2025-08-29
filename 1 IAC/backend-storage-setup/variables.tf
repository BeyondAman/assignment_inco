variable "env"               { type = string }
variable "region"            { type = string }
variable "bucket_name"       { type = string }
variable "enable_kms"        { type = bool   default = true }
variable "allowed_role_arns" { type = list(string) default = [] }
variable "state_key"         { type = string }
variable "tags"              { type = map(string) default = {} }
