# ACM certificate covering apex + wildcard subdomain
# Example: reviews-app-25c-team3.com (apex) + *.reviews-app-25c-team3.com (wildcard)
resource "aws_acm_certificate" "this" {
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"

  # Ensure we have a working cert before destroying the old one (on re-issue)
  lifecycle {
    create_before_destroy = true
  }

  tags = var.tags
}

# DNS validation records in Route53.
# ACM publishes domain_validation_options after the cert is requested;
# we create matching CNAME records here so ACM can verify domain ownership.
resource "aws_route53_record" "validation" {
  for_each = {
    for dvo in aws_acm_certificate.this.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  zone_id         = var.hosted_zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
}

# Blocks until ACM observes the validation records and issues the cert.
# This typically takes 1-5 minutes after the Route53 records propagate.
resource "aws_acm_certificate_validation" "this" {
  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [for r in aws_route53_record.validation : r.fqdn]
}
