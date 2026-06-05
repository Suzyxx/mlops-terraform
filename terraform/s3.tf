# S3 bucket names must be globally unique across ALL of AWS, so this uses a
# random suffix. Change "shanxie" if you like — just keep it lowercase.
resource "aws_s3_bucket" "example" {
  bucket = "mlops-course-01-shanxie-9e23eee0433a"
}
