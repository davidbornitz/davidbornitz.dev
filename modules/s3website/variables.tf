# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

# Input variable definitions

variable "name" {
  description = "DNS name of the site.  Used for s3 bucket. Must be unique."
  type        = string
}

variable "zone_id" {
  description = "Hosted Zone ID where DNS records should be created and validated."
  type        = string
}

variable "cert_arn" {
  description = "ARN of ACM Cert to use on Cloudfront Distribution"
}
