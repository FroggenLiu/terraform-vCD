terraform {
  required_providers {
    vcd = {
      source  = "vmware/vcd"
      version = "~>3.14.0"
    }
    nsxt = {
      source  = "vmware/nsxt"
      version = "~>3.10.0"
    }

  }
}

provider "vcd" {
  url       = var.vcd_url
  org       = var.vcd_org
  user      = var.vcd_user
  password  = var.vcd_password
  allow_unverified_ssl = true
}

provider "nsxt" {
  host                 = var.nsxt_host
  username             = var.nsxt_username
  password             = var.nsxt_password
  allow_unverified_ssl = true
  max_retries          = 2
}

resource "nsxt_policy_tier1_gateway" "enable_t1_adv" {
  display_name  = ""

  route_advertisement_types  = ["TIER1_CONNECTED"]

  lifecycle {
    ignore_changes = [
      enable_firewall,
      enable_standby_relocation,
      failover_mode,
      ha_mode,
      description,
      dhcp_config_path,
      edge_cluster_path,
      id,
      tier0_path,
      tag
    ]
  }
}