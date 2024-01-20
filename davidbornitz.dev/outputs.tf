# Output variable definitions

output "fileset" {
  description = "Fileset found by the module"
  value       = module.s3website["resume.davidbornitz.dev"].fileset
}


