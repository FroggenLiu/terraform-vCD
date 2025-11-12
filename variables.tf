# ---- vCD connection ----
variable "vcd_url" { type = string }
variable "vcd_org" { type = string }
variable "vcd_user" { type = string }
variable "vcd_password" {
  type = string
  sensitive   = true
}

# ---- NSX-T connection ----
variable "nsxt_host" { type = string }
variable "nsxt_username" { type = string }
variable "nsxt_password" {
  type      = string
  sensitive = true
}

## ---- VCD T1 / segment ----
variable "segment_start_ip_addr" {
  type        = string
  description = "Enter segment start ip address. (e.g., 10.1.1.1)"
  validation {
    condition     = can(regex("^(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\\.(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\\.(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\\.(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])$", var.segment_start_ip_addr))
    error_message = "The IP address must be in the format 'x.x.x.x' (e.g., 192.168.1.10)."
  }
}

variable "segment_end_ip_addr" {
  type        = string
  description = "Enter segment end ip address, exclude gateway ip. (e.g., 10.1.1.253)"
  validation {
    condition     = can(regex("^(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\\.(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\\.(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\\.(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])$", var.segment_end_ip_addr))
    error_message = "The IP address must be in the format 'x.x.x.x' (e.g., 192.168.1.10)."
  }
}

variable "segment_gateway_cidr" {
  type        = string
  description = "Enter segment gateway in CIDR format. (e.g., 10.1.1.254/24)"
  validation {
    condition     = can(regex(
      "^(?:(?:25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\\.(?:25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\\.(?:25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\\.(?:25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9]))/(3[0-2]|[12]?[0-9])$", var.segment_gateway_cidr))
    error_message = "The value must be a valid IPv4 CIDR (e.g., 10.1.1.254/24)"
  }
}


variable "orgs" {
  type = map(object({
  full_name = string
  vdcs      = list(object({
    name              = string
    provider_vdc_name = string
    network_pool_name = optional(string, "ip-pool") #fields depending on your environment
    network_quota     = optional(number, 3)
    allocation_model  = string
    cpu_guaranteed    = optional(number, 1.0)
    mem_guaranteed    = optional(number, 1.0)
    enable_thin_provisioning = optional(bool, true)
    compute_capacity  = optional(object({
      cpu = object({
        limit = number
      })
      memory = object({
        limit = number
      })
      enable_thin_provisioning = optional(bool, true)
    }))
    storage_profile   = optional(object({
      name    = string
      limit   = number
      default = bool
      }), {
        name    = "vsan"  #fields depending on your environment
        limit   = 0
        default = true
      })
  }))
    custom_roles = optional(list(object({
      name         = string
      description  = string
      right        = list(string)
  })), [])
    users = list(object({
      name          = string
      password      = string
      role          = string
      full_name     = string
      email_address = string
    }))
  }))
}

#variable "segment_gateway_dns1" {
#  type    = string
#  default = "10.160.1.9"
#}
#variable "segment_gateway_dns2" {
#  type    = string
#  default = "10.160.128.9"
#}

## ---- T0 / segment ----
#variable "t0_name" { type = string}
#variable "edge_cluster_name" { type = string }
#variable "overlay_transport_zone_name" { type = string }
#variable "user_cidr" { type = string }