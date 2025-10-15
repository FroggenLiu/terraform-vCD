vcd_url      = "https:/localhost/api"
vcd_org      = "System"
vcd_user     = "administrator"
vcd_password = "paswwd"

orgs = {
  DemoOrg01 = {
    full_name = "DemoOrg01-main.ol.it-測試01"
    vdcs = [{
      name              = "DemoOrg01-main.ol.it-VDC"
      provider_vdc_name = "tf-cl02"
      allocation_model  = "AllocationVApp"
      compute_capacity = {
        cpu = {
          limit = 0
        }
        memory = {
          limit = 0
        }
      }
      storage_profile = {
        name    = "tf-vsan-raid5"
        limit   = 0
        default = true
      }
    }]
    custom_roles = [{
      name        = "Tenant Admin"
      description = "Tenant Admin"
    }]
    users = [{
      name          = "admin"
      password      = "!QAZ2wsx3edc"
      role          = "Tenant Admin"
      full_name     = "admin"
      email_address = ""
    },{
      name          = "org01-user1"
      password      = "test01"
      role          = "Organization Administrator"
      full_name     = "測試人員1"
      email_address = "test01@cht.com.tw"
    },{
      name          = "org01-user2"
      password      = "test02"
      role          = "Organization Administrator"
      full_name     = "測試人員2"
      email_address = "test02@cht.com.tw"
    }]
  }

  DemoOrg02 = {
    full_name = "DemoOrg02-main.ol.it-測試02"
    vdcs = [{
        name              = "DemoOrg02-main.ol.it-VDC"
        provider_vdc_name = "tf-cl02"
        allocation_model  = "AllocationVApp"
        compute_capacity = {
          cpu = {
            limit = 0
          }
          memory = {
            limit = 0
          }
        }
        storage_profile = {
          name    = "tf-vsan-raid5"
          limit   = 0
          default = true
        }
    }]
    custom_roles = [{
      name        = "Tenant Admin"
      description = "Tenant Admin"
    }]
    users = [{
      name          = "org02-user1"
      password      = "test02"
      role          = "Organization Administrator"
      full_name     = "測試人員2"
      email_address = "test02@cht.com.tw"
    }]
  }
}

