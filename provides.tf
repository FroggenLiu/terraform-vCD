terraform {
  required_providers {
    vcd = {
      source  = "vmware/vcd"
      version = "~>3.14.0"
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
