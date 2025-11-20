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
  url                  = var.vcd_url
  user                 = var.vcd_user
  password             = var.vcd_password
  org                  = var.vcd_org
  allow_unverified_ssl = true
}


provider "nsxt" {
  host                 = var.nsxt_host
  username             = var.nsxt_username
  password             = var.nsxt_password
  allow_unverified_ssl = true
  max_retries          = 2
}
