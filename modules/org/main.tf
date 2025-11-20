terraform {
  required_providers {
    vcd = {
      source  = "vmware/vcd"
      version = "3.14.0"
    }
    nsxt = {
      source  = "vmware/nsxt"
      version = "3.10.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "0.13.1"
    }
  }
}

######################################
# 1. Create an Org
######################################
resource "vcd_org" "this" {
  name        = var.org_name
  full_name   = var.org_full_name
  is_enabled  = true
}

######################################
# 2. Create an Org VDC
######################################
data "nsxt_policy_edge_cluster" "ec" {
  display_name = var.edge_cluster_name
}

resource "vcd_org_vdc" "vdc" {
  for_each = { for v in var.org_vdcs : v.name => v }

  org                       = vcd_org.this.name
  name                      = each.value.name
  allocation_model          = each.value.allocation_model
  provider_vdc_name         = each.value.provider_vdc_name
  network_pool_name         = each.value.network_pool_name
  network_quota             = each.value.network_quota
  enable_thin_provisioning  = each.value.enable_thin_provisioning
  enabled                   = true  # Disable VDC before destruction
  compute_capacity {
    cpu {
      limit = each.value.compute_capacity.cpu.limit
    }
    memory {
      limit = each.value.compute_capacity.memory.limit
    }
  }
  storage_profile {
    name    = each.value.storage_profile.name
    limit   = each.value.storage_profile.limit
    default = each.value.storage_profile.default
  }

  depends_on = [
    vcd_org.this
  ]
}

######################################
# 3. Create a "tenant admin" Role
######################################
data "vcd_role" "org_admin" {
  org  = vcd_org.this.name
  name = "Organization Administrator"

  depends_on = [
    vcd_org_vdc.vdc
  ]
}

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
    data.vcd_role.org_admin
  ]
}

######################################
# 4. add a list of users to VDC
######################################
resource "vcd_org_user" "users" {
  for_each = { for u in var.org_users : u.name => u }

  org           = vcd_org.this.name
  name          = each.value.name
  password      = each.value.password
  role          = each.value.role
  full_name     = each.value.full_name
  email_address = each.value.email_address
  enabled       = true

  depends_on = [
    vcd_role.tenant_admin
  ]
}

######################################
# 5. Create a T1 gateway for vDC from VCD.
######################################
data "vcd_external_network_v2" "ext_net" {
  name = var.external_network_name
}

resource "vcd_nsxt_edgegateway" "t1" {
  for_each = { for v in var.org_vdcs : v.name => v }

  org                 = var.org_name
  owner_id            = vcd_org_vdc.vdc[each.key].id
  name                = "${var.org_name}-T1"
  description         = "provisioned by terraform"
  external_network_id = data.vcd_external_network_v2.ext_net.id
  edge_cluster_id     = data.nsxt_policy_edge_cluster.ec.id

  depends_on = [
    vcd_org_vdc.vdc
  ]
}

######################################
# 6-1. Creat a network(Overlay segment).  NSX-T backend routed Org VDC network
######################################
resource "vcd_network_routed_v2" "overlay_seg" {
  for_each  = var.segment_type == "overlay" ? { for v in var.org_vdcs : v.name => v } : {}

  org             = var.org_name
  name            = "${var.org_name}-segment"
  description     = "provisioned by terraform"
  edge_gateway_id = vcd_nsxt_edgegateway.t1[each.key].id  #attach Edge Gateway(t1)
  gateway         = split("/", var.segment_gateway_cidr)[0]
  prefix_length   = tonumber(split("/", var.segment_gateway_cidr)[1])
  dns1            = var.segment_gateway_dns1
  dns2            = var.segment_gateway_dns2

  static_ip_pool {
    start_address = var.segment_start_ip_addr
    end_address   = var.segment_end_ip_addr
  }

  depends_on = [
    vcd_nsxt_edgegateway.t1
  ]
}


######################################
# 6-2. Creat a network(VLAN segment) from NSX
######################################
######################################
# 6-2. Creat a network(VLAN segment) from NSX
######################################
data "nsxt_policy_transport_zone" "vlan_tz" {
  display_name  = var.vlan_transport_zone_name
}


resource "nsxt_policy_vlan_segment" "vlan_seg"{
  for_each  = var.segment_type == "vlan" ? { for v in var.org_vdcs : v.name => v } : {}

  display_name          = "${vcd_org.this.name}-Segment"
  description           = "provisioned by terraform"
  transport_zone_path   = data.nsxt_policy_transport_zone.vlan_tz.path
  vlan_ids              = [ var.segment_vlan_id ]

  subnet {
    cidr = var.segment_gateway_cidr
  }

  depends_on  = [
    vcd_nsxt_edgegateway.t1,
    data.nsxt_policy_transport_zone.vlan_tz,
  ]
}


######################################
# 6-2-1. bind vlan segment to T1 interface
######################################
locals {
  t1_id = { for k,v in  vcd_nsxt_edgegateway.t1 : k => split(":", v.id)[3] }
}

locals {
  t1_interface_cidr = replace(var.segment_gateway_cidr, "^(\\d+\\.\\d+\\.\\d+)\\.\\d+(/\\d+)$", "$1.254$2")
}

data "nsxt_policy_tier1_gateway" "vlan_t1" {
  for_each  = var.segment_type == "vlan" ? { for v in var.org_vdcs : v.name => v } : {}
  display_name  = "${vcd_org.this.name}-T1-${local.t1_id[each.key]}"
  id            = local.t1_id[each.key]

  depends_on = [ vcd_nsxt_edgegateway.t1 ]
}

resource "nsxt_policy_tier1_gateway_interface" "t1_intf" {
  for_each  = var.segment_type == "vlan" ? { for v in var.org_vdcs : v.name => v } : {}

  display_name  = "${vcd_org.this.name}-Interface"
  description   = "provisioned by terraform"
  gateway_path  = data.nsxt_policy_tier1_gateway.vlan_t1[each.key].path
  segment_path  = nsxt_policy_vlan_segment.vlan_seg[each.key].path
  subnets        = [ local.t1_interface_cidr ]

  depends_on  = [
    nsxt_policy_vlan_segment.vlan_seg,
    data.nsxt_policy_tier1_gateway.vlan_t1,
    local.t1_interface_cidr
  ]
}

######################################
# 6-2-2. create network imported(vlan segment) from VCD
######################################
resource "vcd_nsxt_network_imported" "imported_seg" {
  for_each  = var.segment_type == "vlan" ? { for v in var.org_vdcs : v.name => v } : {}

  name                      = "${vcd_org.this.name}-Segment"
  org                       = var.org_name
  vdc                       = vcd_org_vdc.vdc[each.key].name
  nsxt_logical_switch_name  = nsxt_policy_vlan_segment.vlan_seg[each.key].display_name
#  owner_id                  = vcd_org_vdc.vdc[each.key].id
  gateway                   = split("/", var.segment_gateway_cidr)[0]
  prefix_length             = tonumber(split("/", var.segment_gateway_cidr)[1])

  static_ip_pool {
    start_address = var.segment_start_ip_addr
    end_address   = var.segment_end_ip_addr
  }

  depends_on  = [
    time_sleep.wait_for_vcd_sync_vlan_segment
  ]
}

resource "time_sleep" "wait_for_vcd_sync_vlan_segment" {
  for_each        = var.segment_type == "vlan" ? { for v in var.org_vdcs : v.name => v } : {}
  create_duration = "30s"

  depends_on = [
    nsxt_policy_vlan_segment.vlan_seg,
    nsxt_policy_tier1_gateway_interface.t1_intf
  ]
}


######################################
# 7. Creat a vAPPs and attach to orgVdcNetwork
######################################
resource "vcd_vapp" "vapp" {
  for_each = { for v in var.org_vdcs : v.name => v }

  org         = var.org_name
  vdc         = vcd_org_vdc.vdc[each.key].name
  name        = "${var.org_name}-vAPP"
  description = "provisioned by terraform"
  power_on    = true
  lease       {
    # How long any of the VMs in the vApp can run before the vApp is automatically powered off or suspended. 0 means never expires
    runtime_lease_in_sec  = 0
    # How long the vApp is available before being automatically deleted or marked as expired. 0 means never expires
    storage_lease_in_sec  = 0
  }

  depends_on = [
    vcd_org_vdc.vdc,
  ]
}

resource "vcd_vapp_org_network" "vapp_network" {
  for_each = { for v in var.org_vdcs : v.name => v }

  org               = var.org_name
  vdc               = vcd_org_vdc.vdc[each.key].name
  vapp_name         = vcd_vapp.vapp[each.key].name
  org_network_name  = (
    var.segment_type == "overlay" ? vcd_network_routed_v2.overlay_seg[each.key].name : vcd_nsxt_network_imported.imported_seg[each.key].name
  )
  depends_on = [
    vcd_vapp.vapp,
    time_sleep.wait_for_vcd_sync_vdcOrgNetwork
  ]
}

resource "time_sleep" "wait_for_vcd_sync_vdcOrgNetwork" {
  for_each        = var.segment_type == "vlan" ? { for v in var.org_vdcs : v.name => v } : {}
  create_duration = "30s"

  depends_on = [
    vcd_nsxt_network_imported.imported_seg
  ]
}


######################################
# 6-2-2. ebable T1 route advertisment
######################################

# resource "nsxt_policy_tier1_gateway" "enable_t1_adv" {
#   for_each  = var.segment_type == "vlan" ? { for v in var.org_vdcs : v.name => v } : {}
#   display_name  = "${vcd_org.this.name}-T1-${local.t1_id[each.key]}"
#   route_advertisement_types  = ["TIER1_CONNECTED"]

#   lifecycle {
#     ignore_changes = all
#   }

#   depends_on = [
#     nsxt_policy_tier1_gateway_interface.t1_intf
#   ]
# }

######################################
# Create a T1 gateway
######################################
#data "nsxt_policy_tier0_gateway" "t0" {
#  display_name = var.t0_name
#}
#
#resource "nsxt_policy_tier1_gateway" "t1" {
#  display_name               = "${vcd_org.this.name}-T1"
#  edge_cluster_path          = data.nsxt_policy_edge_cluster.ec.path
#  tier0_path                 = data.nsxt_policy_tier0_gateway.t0.path
#  route_advertisement_types  = ["TIER1_CONNECTED"]
#  failover_mode              = "PREEMPTIVE"
#  enable_firewall            = true
#  pool_allocation            = "ROUTING"
#
#  depends_on = [
#    vcd_org.this,
#    vcd_org_vdc.vdc
#  ]
#}
#
#
#######################################
## Create an Overlay Segment and bind it to T1 gateway
#######################################
#data "nsxt_policy_transport_zone" "overlay_tz" {
#  display_name = var.overlay_transport_zone_name
#}
#
#resource "nsxt_policy_segment" "segment" {
#  display_name         = "${vcd_org.this.name}-Segment"
#  connectivity_path    = nsxt_policy_tier1_gateway.t1.path
#  transport_zone_path  = data.nsxt_policy_transport_zone.overlay_tz.path
#
#  subnet {
#    cidr = var.user_cidr
#  }
#
#  depends_on = [
#    vcd_org.this,
#    nsxt_policy_tier1_gateway.t1
#  ]
#
#}

