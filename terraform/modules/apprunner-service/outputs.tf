# What the module hands back after creating the service.
# service_url is the public hostname where the running app is reachable.
output "service_url" {
  description = "Public HTTPS hostname App Runner serves the app on."
  value       = aws_apprunner_service.ars.service_url
}

output "arn" {
  description = "ARN of the App Runner service."
  value       = aws_apprunner_service.ars.arn
}

output "status" {
  description = "Current status of the App Runner service (e.g. RUNNING)."
  value       = aws_apprunner_service.ars.status
}
