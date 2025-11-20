#fields depending on your environment
vcd_url      = "" 
vcd_org      = ""
vcd_user     = ""
vcd_password = ""

#fields depending on your environment
nsxt_host = ""
nsxt_username = ""
nsxt_password = ""

#t0_name = "tier-0"
#edge_cluster_name = "edge-cluster"
#overlay_transport_zone_name = "tz-overlay01"

orgs = {
  DemoOrg01 = {
    full_name = "" #fields depending on your environment
    vdcs = [{
      name              = ""              #fields depending on your environment
      provider_vdc_name = ""              #fields depending on your environment
      network_pool_name = ""              #fields depending on your environment
      allocation_model  = "AllocationVApp"#fields depending on your environment
      enable_thin_provisioning = true
      compute_capacity = {
        cpu = {
          limit = 0
        }
        memory = {
          limit = 0
        }
      }
      storage_profile = {
        name    = "" #fields depending on your environment
        limit   = 0
        default = true
      }
      custom_roles = [{
        name        = "Tenant Admin" #fields depending on your environment
        description = "Tenant Admin" #fields depending on your environment
        right       = [
           "Organization vDC Network: Edit Properties" #fields depending on your environment
        ]
      }]
    }]
    users = [{
      #fields depending on your environment
      name          = "" 
      password      = ""  
      role          = ""  
      full_name     = ""  
      email_address = ""
    },{
      #fields depending on your environment
      name          = ""  
      password      = ""  
      role          = ""  
      full_name     = ""
      email_address = ""
    }]
  }

  # DemoOrg02 = {
  #   full_name = "2"
  #   vdcs = [{
  #       name              = ""
  #       provider_vdc_name = ""
  #       allocation_model  = "AllocationVApp"
  #       enable_thin_provisioning = true
  #       compute_capacity = {
  #         cpu = {
  #           limit = 0
  #         }
  #         memory = {
  #           limit = 0
  #         }
  #       }
  #       storage_profile = {
  #         name    = ""
  #         limit   = 0
  #         default = true
  #       }
  #       custom_roles = [{
  #         name        = "Tenant Admin"
  #         description = "Tenant Admin"
  #         right       = [
  #           "Organization vDC Network: Edit Properties"
  #         ]
  #       }]
  #   }]
  #   users = [{
  #     name          = "org02-user1"
  #     password      = "test02"
  #     role          = "Organization Administrator"
  #     full_name     = ""
  #     email_address = ""
  #   }]
  # }
}


