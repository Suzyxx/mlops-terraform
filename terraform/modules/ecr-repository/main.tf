# Reusable building block: "how we make one ECR repository."
# ECR (Elastic Container Registry) is a private shelf in AWS that stores Docker
# images. App Runner can't pull an image from your laptop, so the image needs a
# cloud home first. The caller passes the name/config in; the module stays generic.
resource "aws_ecr_repository" "ecr" {
  name = var.name

  # MUTABLE = a tag like ":latest" can be overwritten by a new push (handy while
  # iterating). IMMUTABLE = tags are write-once (safer for real production).
  image_tag_mutability = var.image_tag_mutability

  # Scan each pushed image for known OS/library vulnerabilities (free, push-time).
  image_scanning_configuration {
    scan_on_push = var.image_scanning_configuration.scan_on_push
  }

  tags = var.tags
}
