provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

locals {
  enabled_parse_domain_records = {
    for key, record in var.parse_domain_records : key => record
    if record.enabled
  }

  planned_mx_records = {
    for key, record in local.enabled_parse_domain_records : key => {
      zone_key     = record.zone_key
      zone_id      = var.zones[record.zone_key].zone_id
      parse_domain = record.parse_domain
      name         = record.mx_name
      content      = "inbound-smtp.${var.ses_region}.amazonaws.com"
      priority     = record.mx_priority
      ttl          = record.ttl
      proxied      = false
      type         = "MX"
    }
  }

  planned_identity_records = {
    for key, record in local.enabled_parse_domain_records : key => {
      zone_key               = record.zone_key
      zone_id                = var.zones[record.zone_key].zone_id
      parse_domain           = record.parse_domain
      has_verification_token = record.verification_token != null
      dkim_token_count       = length(record.dkim_tokens)
      ttl                    = record.ttl
      proxied                = false
    }
  }
}

# SPF, DMARC, Resend, iCloud, Apple verification, app routing records, and
# product Cloudflare settings are deliberately outside this shared SES boundary.
