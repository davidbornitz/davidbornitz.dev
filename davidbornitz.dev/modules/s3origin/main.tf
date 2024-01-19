# Terraform configuration

locals {
  # Look up content extensions to set MIME type
  content_types = {
    ".html" : "text/html",
    ".css" : "text/css",
    ".js" : "text/javascript"
  }
}

resource "aws_s3_bucket" "bucket" {
  bucket = var.name
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

# Initially allow Cloudfront service access.  This is restricted later.
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
  }
}

resource "aws_s3_object" "website" {
  for_each      = fileset("${path.module}/../content/${var.name}", "**")
  bucket        = aws_s3_bucket.bucket.id
  key           = each.key
  source        = "${path.module}/content/${each.value}"
  etag          = filemd5("${path.module}/content/${each.value}")
  content_type  = lookup(local.content_types, regex("\\.[^.]+$", each.value), null)
  cache_control = "max-age=0"
}