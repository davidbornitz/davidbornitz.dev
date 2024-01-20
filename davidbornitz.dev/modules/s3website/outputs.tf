# Output variable definitions

output "bucket_arn" {
  description = "ARN of the bucket"
  value       = aws_s3_bucket.bucket.arn
}

output "bucket_id" {
  description = "ID of the bucket"
  value       = aws_s3_bucket.bucket.id
}

output "bucket_regional_domain_name" {
  description = "Bucket regional dns endpoint"
  value       = aws_s3_bucket.bucket.bucket_regional_domain_name
}

output "filset" {
  value = local.fileset
}


