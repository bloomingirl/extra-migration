variable "domain_name" {
  description = "Primary domain name for the certificate (e.g. reviews-app-25c-team3.com). Also covers wildcard *.domain_name"
  type        = string
}

variable "hosted_zone_id" {
  description = "Route53 hosted zone ID where DNS validation records will be created"
  type        = string
}

variable "tags" {
  description = "Tags to apply to the certificate"
  type        = map(string)
  default     = {}
}
