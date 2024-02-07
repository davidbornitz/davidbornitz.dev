# terragrunt-test.hcl
include "root" {
  path   = "/Users/dbornitz/davidbornitz.dev/terragrunt.hcl"#find_in_parent_folders()
}

terraform {
  source = "git::github.com/davidbornitz/s3website.git?ref=v0.0.1"
}

inputs = {
  name = "test.davidbornitz.dev"
  zone_id  = "Z04601461HBLV7APEL0VR"
  cert_arn = "arn:aws:acm:us-east-1:085879623427:certificate/0c98caac-a15d-43ff-acfb-5215ebc4a3fb"
}