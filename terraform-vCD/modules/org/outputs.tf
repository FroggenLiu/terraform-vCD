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
  value = { for user in vcd_org_user.users : user.name => user.role }
}

output "t1_id" {
  value       = var.segment_type == "vlan" ? { for k, v in local.t1_id : k => v } : {}
  description = "The NSX-T Tier-1 Gateway ID for each VDC"
}

