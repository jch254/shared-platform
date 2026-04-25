output "aws_region" {
  description = "Default AWS region used for local/backend-compatible conventions."
  value       = var.aws_region
}

output "ses_region" {
  description = "AWS region for SES inbound receiving."
  value       = var.ses_region
}

output "environment" {
  description = "Deployment environment label."
  value       = var.environment
}

output "route_keys" {
  description = "All configured route keys."
  value       = keys(var.routes)
}

output "enabled_route_keys" {
  description = "Route keys enabled for future SES routing."
  value       = keys(local.enabled_routes)
}

output "route_summaries" {
  description = "Non-secret route contract summary for review before state ownership or live changes."
  value       = local.route_summaries
}

output "receipt_rule_set_name" {
  description = "Name of the modeled shared SES receipt rule set. Activation remains disabled."
  value       = module.ses_receipt_rule_set.name
}

output "modeled_route_names" {
  description = "Names of the modeled live SES receipt rules."
  value = [
    module.gtd_inbound_rule.name,
    module.music_submission_rule.name,
  ]
}

output "modeled_recipients" {
  description = "Recipients modeled for each live SES route."
  value = {
    gtd_inbound      = local.modeled_routes.gtd_inbound.recipients
    music_submission = local.modeled_routes.music_submission.recipients
  }
}
