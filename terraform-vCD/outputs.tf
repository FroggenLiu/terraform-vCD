# Output t1_id from all org modules
# This will be a map of org_name => { vdc_name => t1_id }
output "t1_ids" {
  value       = { for k, v in module.orgs : k => v.t1_id }
  description = "Map of organization names to their Tier-1 Gateway IDs"
}

# Output the first t1_id for convenience (useful when there's only one org)
output "t1_id" {
  value       = length(module.orgs) > 0 ? values(module.orgs)[0].t1_id : {}
  description = "Tier-1 Gateway IDs from the first organization (for convenience)"
}

# Output t1_display_name from all org modules
# This will be a map of org_name => { vdc_name => t1_display_name }
output "t1_display_names" {
  value       = { for k, v in module.orgs : k => v.t1_display_name }
  description = "Map of organization names to their Tier-1 Gateway display names"
}

# Output the first t1_display_name for convenience (useful when there's only one org)
output "t1_display_name" {
  value       = length(module.orgs) > 0 ? values(module.orgs)[0].t1_display_name : {}
  description = "Tier-1 Gateway display names from the first organization (for convenience)"
}

# Output t1_path from all org modules
# This will be a map of org_name => { vdc_name => t1_path }
output "t1_paths" {
  value       = { for k, v in module.orgs : k => v.t1_path }
  description = "Map of organization names to their Tier-1 Gateway paths"
}

# Output the first t1_path for convenience (useful when there's only one org)
output "t1_path" {
  value       = length(module.orgs) > 0 ? values(module.orgs)[0].t1_path : {}
  description = "Tier-1 Gateway paths from the first organization (for convenience)"
}