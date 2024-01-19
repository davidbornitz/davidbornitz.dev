# Input variable definitions

variable "bucket_id" {
  description = "ID of the origin bucket"
  type        = string
}

variable "bucket_arn" {
  description = "ARN of the origin bucket"
  type        = string
}

variable "cloudfront_arn" {
  description = "ARN of fronting Cloudfront distribution"
  type        = string
}