output "org_name" {
    value = vcd_org.this.name
}

output "vdc_name" {
    value = [ for v in vcd_org_vdc.vdc : v.name ]
}

output "user_name" {
    value = [ for u in vcd_org_user.users : u.name ]
}

output "user_roles_map" {
  value = { for k, user in vcd_org_user.users : user.name => user.role }
}

output "base_bundle_rights_list" {
  value = tolist(data.vcd_rights_bundle.base_bundle["VDC-NAME"].rights) }