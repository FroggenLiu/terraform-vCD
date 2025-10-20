variable "vcd_url" { type = string }
variable "vcd_org" { type = string }
variable "vcd_user" { type = string }
variable "vcd_password" {
  type = string
  sensitive   = true
}

variable "orgs" {
  type = map(object({
  full_name = string
  vdcs      = list(object({
    name              = string		
    provider_vdc_name = string
    allocation_model 	= string
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
        name	  = "tf-vsan-raid5"
        limit	  = 0
        default = true
      })
  }))
    custom_roles = optional(list(object({
      name         = string
      description  = string
      right        = list(string)
  })), [])
    users	= list(object({
      name          = string
      password      = string
      role          = string
      full_name     = string
      email_address = string
    }))
  }))
}

