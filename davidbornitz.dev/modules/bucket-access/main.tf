# Module that attaches a bucket policy to each s3 origin to restrict traffic to the Cloudfront distribution

resource "aws_s3_bucket_policy" "allow_cloudfront_access" {
  bucket = var.bucket_id
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
      "${var.bucket_arn}/*",
    ]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"

      values = [
        "${var.cloudfront_arn}"
      ]
    }
  }
}