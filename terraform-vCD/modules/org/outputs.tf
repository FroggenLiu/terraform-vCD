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

output "t1_path" {
  value       = var.segment_type == "vlan" ? { for k, v in data.nsxt_policy_tier1_gateway.vlan_t1 : k => v.path } : {}
  description = "The NSX-T Tier-1 Gateway display name for each VDC"
}

output "t1_display_name" {
  value       = var.segment_type == "vlan" ? { for k, v in data.nsxt_policy_tier1_gateway.vlan_t1 : k => v.display_name } : {}
  description = "The NSX-T Tier-1 Gateway display name for each VDC"
}


