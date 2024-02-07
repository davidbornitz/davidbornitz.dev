locals {
  sites = [
    "davidbornitz.dev",
    "resume.davidbornitz.dev"
  ]
}

module "s3website" {
  source = "./modules/s3website"

  for_each = toset(local.sites)

  name     = each.value
  zone_id  = aws_route53_zone.davidbornitz.zone_id
  cert_arn = aws_acm_certificate.davidbornitz.arn
}


module "invitations" {
  source = "./modules/invitations"

  name     = "invitation.davidbornitz.dev"
  zone_id  = aws_route53_zone.davidbornitz.zone_id
  cert_arn = aws_acm_certificate.davidbornitz.arn
}


resource "aws_cloudfront_origin_access_control" "davidbornitz" {
  name                              = "davidbornitz"
  description                       = "Allow Only Cloudfront"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_acm_certificate" "davidbornitz" {
  provider                  = aws.us-east-1
  domain_name               = "*.davidbornitz.dev"
  subject_alternative_names = ["davidbornitz.dev"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_zone" "davidbornitz" {
  name = "davidbornitz.dev"
}

resource "aws_acm_certificate_validation" "davidbornitz" {
  provider                = aws.us-east-1
  certificate_arn         = aws_acm_certificate.davidbornitz.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.davidbornitz.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.davidbornitz.zone_id
}
