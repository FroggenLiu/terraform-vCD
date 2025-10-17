terraform {
  required_providers {
    vcd = {
      source  = "vmware/vcd"
      version = "~> 3.14.0"
    }
  }
}

# IMPORTANT: To create new organizations, the provider must be configured
# with the "System" organization. Make sure var.vcd_org is set to "System"
# and var.vcd_user has system administrator privileges.
provider "vcd" {
  url                  = var.vcd_url
  user                 = var.vcd_user
  password             = var.vcd_password
  org                  = var.vcd_org  # Must be "System" to create organizations
  allow_unverified_ssl = true
}
