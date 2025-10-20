terraform {
  required_providers {
    vcd = {
      source  = "vmware/vcd"
      version = "~> 3.14.0"
    }
  }
}

provider "vcd" {
  url                  = "https://vcd/api"
  user                 = "administrator"
  password             = "password"
  org                  = "System"
  allow_unverified_ssl = true
}
