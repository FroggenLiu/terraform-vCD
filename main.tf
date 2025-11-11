module "orgs" {
  source = "./modules/org"
  providers = {
    vcd   = vcd
    nsxt  = nsxt
  }

  for_each = var.orgs

  org_name              = each.key
  org_full_name         = each.value.full_name
  org_users             = each.value.users
  org_vdcs              = each.value.vdcs
  segment_gateway_cidr  = var.segment_gateway_cidr
  segment_start_ip_addr = var.segment_start_ip_addr
  segment_end_ip_addr   = var.segment_end_ip_addr
}
