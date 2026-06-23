variable "hosted_zone_id" {
  description = "Route53 hosted zone ID for the domain"
  type        = string
}

variable "domain_name" {
  description = "Root domain name managed by external-dns and ACM"
  type        = string
}
