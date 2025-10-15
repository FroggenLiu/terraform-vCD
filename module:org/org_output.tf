output "org_name" {
    value = vcd_org.this.name
}

output "vdc_name" {
    value = [ for v in vcd_org_vdc.vdc : v.name ]
}

output "user_name" {
    value = [ for u in vcd_org_user.users : u.name ]
}


