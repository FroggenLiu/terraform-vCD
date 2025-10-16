terraform {
  required_providers {
    vcd = {
      source  = "vmware/vcd"
      version = "~> 3.14.0"
    }
  }
}

data "vcd_rights_bundle" "base_bundle" {
  for_each = {
    for vdc in var.org_vdcs : vdc.name => vdc
    if length(vdc.custom_roles) > 0
  }
  name = "Organization Administrator"
}

resource "vcd_org" "this" {
  name        = var.org_name
  full_name   = var.org_full_name
  is_enabled  = true
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

  depends_on    = [
    vcd_org.this
  ]
}

resource "vcd_org_vdc" "vdc" {
  for_each = { for v in var.org_vdcs : v.name => v }

  org               = vcd_org.this.name
  name              = each.value.name
  allocation_model  = each.value.allocation_model
  provider_vdc_name = each.value.provider_vdc_name
  compute_capacity {
    cpu {
      limit = try(each.value.compute_capacity.cpu)
    }
    memory {
      limit = try(each.value.compute_capacity.memory)
    }
  }
  storage_profile {
    name = each.value.storage_profile.name
    limit = each.value.storage_profile.limit
    default = each.value.storage_profile.default
  }

    depends_on = [
    vcd_org.this
  ]
}

resource "vcd_role" "custom" {
  for_each = {
    for vdc in var.org_vdcs : vdc.name => vdc
    if length(vdc.custom_roles) > 0
  }
  
  name        = each.value.custom_roles[0].name
  description = each.value.custom_roles[0].description
  org         = vcd_org.this.name
  vdc         = each.value.name

  excluded_right = "Organization vDC Network: Edit Properties"
  base_rights = data.vcd_rights_bundle.base_bundle[each.key].rights

  rights = tolist(setsubtract(
    toset(base_rights),
    toset([excluded_right])
  ))
}