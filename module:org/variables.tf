variable "org_name" {}
variable "org_full_name" {}
variable "org_users" {
  type = list(object({
    name        	= string
    password    	= string
    role	    	  = string
    full_name   	= string
    email_address = string
  }))
}

variable "org_vdcs" {
  type = list(object({
    name = string		
    provider_vdc_name = string
    allocation_model 	= string
    cpu_guaranteed		= optional(number, 1.0)
    mem_guaranteed		= optional(number, 1.0)
    compute_capacity  = optional(object({
      cpu = object({
        limit = number
      })
      memory = object({
        limit = number
      })
    }))
    storage_profile		= optional(object({
      name		= string
      limit 	= number
      default = bool
    }), {
      name	  = "tf-vsan-raid05"
      limit	  = 0
      default	= true
		})
	}))
}
