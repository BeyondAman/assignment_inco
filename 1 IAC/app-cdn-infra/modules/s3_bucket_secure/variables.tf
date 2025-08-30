variable "name"       { type = string }

variable "region"     { type = string }

variable "enable_kms" { 
  type = bool 
  default = true 

}
variable "tags"       { 
  type = map(string)
  default = {}
}
