terraform {
  required_providers {
    vcd = {
      source  = "vmware/vcd"
      version = "3.14.0"
    }
  }
}

data "vcd_role" "org_admin" {
  org  = vcd_org.this.name
  name = "Organization Administrator"

  depends_on = [
    vcd_org.this
  ]
}

resource "vcd_org" "this" {
  name        = var.org_name
  full_name   = var.org_full_name
  is_enabled  = true
}

# Org-level custom role: Org Admin rights minus one
resource "vcd_role" "tenant_admin" {
  org         = vcd_org.this.name
  name        = "Tenant Admin"
  description = "Tenant Admin"

  rights = tolist(setsubtract(
    toset(data.vcd_role.org_admin.rights),
    toset([
      "Organization vDC Network: Edit Properties"
    ])
  ))

  depends_on = [
    vcd_org.this,
    data.vcd_role.org_admin
  ]
}

resource "vcd_org_user" "users" {
  for_each = { for u in var.org_users : u.name => u }
  
  org         	= vcd_org.this.name
  name        	= each.value.name
  password    	= each.value.password
  role          = each.value.role
  full_name   	= each.value.full_name
  email_address = each.value.email_address
  enabled       = true

  depends_on = [
    vcd_org.this,
    vcd_role.tenant_admin
  ]
}

resource "vcd_org_vdc" "vdc" {
  for_each = { for v in var.org_vdcs : v.name => v }

  org               = vcd_org.this.name
  name              = each.value.name
  allocation_model  = each.value.allocation_model
  provider_vdc_name = each.value.provider_vdc_name
  enable_thin_provisioning = each.value.enable_thin_provisioning
  compute_capacity {
    cpu {
      limit = each.value.compute_capacity.cpu.limit
    }
    memory {
      limit = each.value.compute_capacity.memory.limit
    }
  }
  storage_profile {
    name = each.value.storage_profile.name
    limit = each.value.storage_profile.limit
    default = each.value.storage_profile.default
  }

  depends_on = [
    vcd_org.this,
    vcd_org_user.users
  ]
}