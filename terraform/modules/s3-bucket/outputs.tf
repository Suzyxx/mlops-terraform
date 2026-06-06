# What the module hands back to the caller after creating the bucket.
output "data" {
  description = "The full S3 bucket object (arn, id, region, etc.)."
  value       = aws_s3_bucket.s3
}
