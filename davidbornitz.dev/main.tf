terraform {

  backend "s3" {
    bucket         = "dbornitz-tfstate-1ef8"
    key            = "state/terraform.tfstate"
    region         = "us-east-2"
    encrypt        = true
    dynamodb_table = "app-state"
  }
}

provider "aws" {
  region = "us-east-2"
}

provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}

locals {
  sites = [
    "davidbornitz.dev",
    "resume.davidbornitz.dev"
  ]
}

module "s3origin" {
  source = "./modules/s3origin"

  for_each = toset(local.sites)

  name = each.value
  #cloudfront_arn = aws_cloudfront_distribution.davidbornitz.arn
  zone_id = aws_route53_zone.davidbornitz.zone_id
}

module "bucket-access" {
  source = "./modules/bucket-access"

  for_each = module.s3origin

  bucket_id      = each.value.bucket_id
  bucket_arn     = each.value.bucket_arn
  cloudfront_arn = aws_cloudfront_distribution.davidbornitz.arn
}

resource "aws_route53_record" "record" {
  for_each = toset(local.sites)
  zone_id  = aws_route53_zone.davidbornitz.zone_id
  name     = each.value
  type     = "A"

  alias {
    name                   = aws_cloudfront_distribution.davidbornitz.domain_name
    zone_id                = aws_cloudfront_distribution.davidbornitz.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_cloudfront_distribution" "davidbornitz" {
  depends_on = [aws_acm_certificate_validation.davidbornitz]

  dynamic "origin" {
    for_each = module.s3origin
    content {
      domain_name              = module.s3origin[origin.key].bucket_regional_domain_name
      origin_access_control_id = aws_cloudfront_origin_access_control.davidbornitz.id
      origin_id                = module.s3origin[origin.key].bucket_id
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  aliases = local.sites

  default_cache_behavior {
    allowed_methods  = ["HEAD", "GET"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "resume.davidbornitz.dev"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
      locations        = []
    }
  }


  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.davidbornitz.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}

resource "aws_cloudfront_origin_access_control" "davidbornitz" {
  name                              = "davidbornitz"
  description                       = "Allow Only Cloudfront"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_acm_certificate" "davidbornitz" {
  provider          = aws.us-east-1
  domain_name       = "*.davidbornitz.dev"
  validation_method = "DNS"

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
