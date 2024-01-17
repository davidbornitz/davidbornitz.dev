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
  content_types = {
    ".html" : "text/html",
    ".css" : "text/css",
    ".js" : "text/javascript"
  }
}

resource "aws_s3_bucket" "resume" {
  bucket = "dbornitz-resume"
}

resource "aws_s3_bucket_website_configuration" "resume" {
  bucket = aws_s3_bucket.resume.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }

}

resource "aws_s3_bucket_public_access_block" "resume" {
  bucket = aws_s3_bucket.resume.id

  block_public_acls   = false
  block_public_policy = false
}

resource "aws_s3_object" "resume_website" {
  for_each      = fileset("${path.module}/content", "**")
  bucket        = aws_s3_bucket.resume.id
  key           = each.key
  source        = "${path.module}/content/${each.value}"
  etag          = filemd5("${path.module}/content/${each.value}")
  content_type  = lookup(local.content_types, regex("\\.[^.]+$", each.value), null)
  cache_control = "max-age=0"
}

resource "aws_s3_bucket_policy" "allow_cloudfront_access" {
  bucket = aws_s3_bucket.resume.id
  policy = data.aws_iam_policy_document.allow_cloudfront_access.json
}

data "aws_iam_policy_document" "allow_cloudfront_access" {
  statement {
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions = [
      "s3:GetObject"
    ]

    resources = [
      "${aws_s3_bucket.resume.arn}/*",
    ]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"

      values = [
        "${aws_cloudfront_distribution.resume.arn}"
      ]
    }
  }
}

resource "aws_cloudfront_distribution" "resume" {
  depends_on = [ aws_acm_certificate_validation.resume ]
  origin {
    domain_name              = aws_s3_bucket.resume.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.resume.id
    origin_id                = "resume"
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  aliases = ["resume.davidbornitz.dev"]

  default_cache_behavior {
    allowed_methods  = ["HEAD", "GET"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "resume"

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
    acm_certificate_arn      = aws_acm_certificate.resume.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}

resource "aws_cloudfront_origin_access_control" "resume" {
  name                              = "resume"
  description                       = "Allow Only Cloudfront"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_acm_certificate" "resume" {
  provider          = aws.us-east-1
  domain_name       = "*.davidbornitz.dev"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_zone" "davidbornitz_dev" {
  name = "davidbornitz.dev"
}

resource "aws_route53_record" "resume" {
  zone_id = aws_route53_zone.davidbornitz_dev.zone_id
  name    = "resume.davidbornitz.dev"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.resume.domain_name
    zone_id                = aws_cloudfront_distribution.resume.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "resume_validation" {
  for_each = {
    for dvo in aws_acm_certificate.resume.domain_validation_options : dvo.domain_name => {
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
  zone_id         = aws_route53_zone.davidbornitz_dev.zone_id
}

resource "aws_acm_certificate_validation" "resume" {
  provider                = aws.us-east-1
  certificate_arn         = aws_acm_certificate.resume.arn
  validation_record_fqdns = [for record in aws_route53_record.resume_validation : record.fqdn]
}
