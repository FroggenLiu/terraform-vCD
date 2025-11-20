variable "nsxt_host" { type = string }
variable "nsxt_username" { type = string }
variable "nsxt_password" {
  type        = string
  sensitive   = true
}

variable "vcd_url" { type = string }
variable "vcd_org" { type = string }
variable "vcd_user" { type = string }
variable "vcd_password" {
  type        = string
  sensitive   = true
}