# Surface the useful endpoints after `terraform apply`.
output "ecr_repository_urls" {
  description = "URLs of the created ECR repositories (push/pull addresses)."
  value       = { for k, m in module.ecr_repository : k => m.repository_url }
}

output "apprunner_service_urls" {
  description = "Public URLs of the created App Runner services."
  value       = { for k, m in module.apprunner_service : k => m.service_url }
}
