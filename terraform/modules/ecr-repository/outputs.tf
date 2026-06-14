# What the module hands back after creating the repository.
# The URL is the address we tag/push images to AND the address App Runner pulls
# from, e.g. <account>.dkr.ecr.<region>.amazonaws.com/<name>.
output "repository_url" {
  description = "URL of the ECR repository (used to tag/push images and for App Runner to pull)."
  value       = aws_ecr_repository.ecr.repository_url
}

output "arn" {
  description = "ARN of the ECR repository."
  value       = aws_ecr_repository.ecr.arn
}
