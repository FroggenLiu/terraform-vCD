module "orgs" {
  source = "./modules/org"
  providers = {
    vcd = vcd
  }

  for_each = var.orgs

  org_name      = each.key
  org_full_name = each.value.full_name
  org_users     = each.value.users
  org_vdcs      = each.value.vdcs
}
