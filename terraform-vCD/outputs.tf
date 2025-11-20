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

