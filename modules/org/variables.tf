variable "org_name" {}
variable "org_full_name" {}
variable "org_users" {
  type = list(object({
    name          = string
    password      = string
    role          = string
    full_name     = string
    email_address = string
  }))
}

variable "t0_name" {
  type    = string
  default = "tier-0" #fields depending on your environment
}
variable "edge_cluster_name" {
  type    = string
  default = "edge-cluster" #fields depending on your environment
}
variable "overlay_transport_zone_name" {
  type    = string
  default = "overlay_transport_zone" #fields depending on your environment
}
variable "external_network_name" {
  type    = string
  default = "external_network" #fields depending on your environment
}
variable "segment_gateway_cidr" {
  type = string
}
variable "segment_start_ip_addr" {
  type = string
}
variable "segment_end_ip_addr" {
  type = string
}
variable "segment_gateway_dns1" {
  type    = string
  default = "8.8.8.8" #fields depending on your environment
}
variable "segment_gateway_dns2" {
  type    = string
  default = "8.8.8.8" #fields depending on your environment
}


variable "org_vdcs" {
  type = list(object({
    name = string
    provider_vdc_name = string
    allocation_model  = string
    network_pool_name = string
    network_quota     = optional(number, 3)
    cpu_guaranteed    = optional(number, 1.0)
    mem_guaranteed    = optional(number, 1.0)
    enable_thin_provisioning = optional(bool, true)
    compute_capacity  = object({
      cpu = object({ limit = number })
      memory = object({ limit = number })
    })
    storage_profile   = optional(object({
      name    = string
      limit   = number
      default = bool
    }), {
      name    = "vsan" #fields depending on your environment
      limit   = 0
      default = true
    })
    custom_roles = optional(list(object({
      name        = string
      description = string
      right       = optional(list(string), [])
    })), [])
  }))
}

