# Terraform configuration

locals {
  # Look up content extensions to set MIME type
  content_types = {
    ".html" : "text/html",
    ".css" : "text/css",
    ".js" : "text/javascript"
  }

  fileset = fileset("../../content/${var.name}/", "**")
}

resource "random_id" "bucket" {
  byte_length = 4
}

resource "aws_s3_bucket" "bucket" {
  bucket = "${var.name}-${random_id.bucket.hex}"
}

resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }

}

resource "aws_s3_bucket_policy" "allow_cloudfront_access" {
  bucket = aws_s3_bucket.bucket.id
  policy = data.aws_iam_policy_document.allow_cloudfront_access.json
}

resource "aws_s3_object" "website" {
  for_each      = local.fileset
  bucket        = aws_s3_bucket.bucket.id
  key           = each.key
  source        = "../content/${var.name}/${each.value}"
  etag          = filemd5("${path.module}/content/${var.name}/${each.value}")
  content_type  = lookup(local.content_types, regex("\\.[^.]+$", each.value), null)
  cache_control = "max-age=0"
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
      "${aws_s3_bucket.bucket.arn}/*",
    ]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"

      values = [
        "${aws_cloudfront_distribution.davidbornitz.arn}"
      ]
    }
  }
}


resource "aws_cloudfront_distribution" "davidbornitz" {

  origin {
      domain_name              = aws_s3_bucket.bucket.bucket_regional_domain_name
      origin_access_control_id = aws_cloudfront_origin_access_control.davidbornitz.id
      origin_id                = var.name
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["HEAD", "GET"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = var.name

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
    acm_certificate_arn      = var.cert_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}

resource "aws_cloudfront_origin_access_control" "davidbornitz" {
  name                              = "davidbornitz-${random_id.bucket.hex}"
  description                       = "Allow Only Cloudfront"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}
