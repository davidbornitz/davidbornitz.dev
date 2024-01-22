# Terraform configuration

locals {
  # Look up content extensions to set MIME type
  content_types = {
    ".html" : "text/html",
    ".css" : "text/css",
    ".js" : "text/javascript"
  }

  content_path = "${path.module}/../../content/${var.name}/"
  key_path = "${path.module}/../../"

  fileset = fileset(local.content_path, "**") # ${var.name}
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
  source        = "${local.content_path}/${each.value}"
  etag          = filemd5("${local.content_path}/${each.value}")
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
        "${aws_cloudfront_distribution.invitation.arn}"
      ]
    }
  }
}

resource "aws_route53_record" "record" {
  zone_id  = var.zone_id
  name     = var.name
  type     = "A"

  alias {
    name                   = aws_cloudfront_distribution.invitation.domain_name
    zone_id                = aws_cloudfront_distribution.invitation.hosted_zone_id
    evaluate_target_health = false
  }
}


resource "aws_cloudfront_distribution" "invitation" {

  origin {
      domain_name              = aws_s3_bucket.bucket.bucket_regional_domain_name
      origin_access_control_id = aws_cloudfront_origin_access_control.davidbornitz.id
      origin_id                = var.name
  }

  aliases = [var.name]

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  default_cache_behavior {
    trusted_key_groups = [aws_cloudfront_key_group.invitation.id]

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

resource "aws_cloudfront_public_key" "invitation" {
  comment     = "Public key for signing invitations"
  encoded_key = file("${local.key_path}/public_key_invitation.pem")
  name        = "invitation-key"
}

resource "aws_cloudfront_key_group" "invitation" {
  comment = "Invitation key group"
  items   = [aws_cloudfront_public_key.invitation.id]
  name    = "invitation-key-group"
}

# Create a Dynamo table to hold Super Bowl Potluck signups

resource "aws_dynamodb_table" "invitation" {
  name           = "invitation"
  read_capacity  = 5
  write_capacity = 5
  hash_key       = "Name"

  attribute {
    name = "Name"
    type = "S"
  }

  ttl {
    attribute_name = "TimeToExist"
    enabled        = false
  }
}

# Create a Cognito Identity Pool to grant unauthenticated users AWS access
resource "aws_cognito_identity_pool" "invitation" {
  identity_pool_name               = "invitation"
  allow_unauthenticated_identities = true
  allow_classic_flow               = false
}

data "aws_iam_policy_document" "invitation" {
  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = ["cognito-identity.amazonaws.com"]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "cognito-identity.amazonaws.com:aud"
      values   = [aws_cognito_identity_pool.invitation.id]
    }

    condition {
      test     = "ForAnyValue:StringLike"
      variable = "cognito-identity.amazonaws.com:amr"
      values   = ["unauthenticated"]
    }
  }
}

resource "aws_iam_role" "invitation" {
  name               = "invitation"
  assume_role_policy = data.aws_iam_policy_document.invitation.json
}

data "aws_iam_policy_document" "invitation_role_policy" {
  statement {
    effect = "Allow"

    actions = [
      "cognito-sync:*",
      "cognito-identity:*"
    ]

    resources = ["*"]
  }
  statement {
    effect = "Allow"

    actions = [
      "dynamodb:PutItem"
    ]

    resources = [aws_dynamodb_table.invitation.arn]
  }
}

resource "aws_iam_role_policy" "invitation" {
  name   = "invitation_policy"
  role   = aws_iam_role.invitation.id
  policy = data.aws_iam_policy_document.invitation_role_policy.json
}

resource "aws_cognito_identity_pool_roles_attachment" "invitation" {
  identity_pool_id = aws_cognito_identity_pool.invitation.id

  roles = {
    "unauthenticated" = aws_iam_role.invitation.arn
  }
}

resource "aws_sns_topic" "invitation_updates" {
  name = "invitation-updates"
}

resource "aws_sns_topic_subscription" "invitation" {
  topic_arn = aws_sns_topic.invitation_updates.arn
  protocol  = "email"
  endpoint  = "davidbornitz@gmail.com"
}