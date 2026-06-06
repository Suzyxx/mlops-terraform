# The reusable building block: "how we make one S3 bucket."
# It knows nothing about environments or naming — the caller passes those in.
resource "aws_s3_bucket" "s3" {
  bucket = var.bucket
  tags   = var.tags
}
