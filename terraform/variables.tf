# Root-level inputs. Defaults here are overridden per stage by environments/<env>.tfvars.
variable "aws_region" {
  description = "AWS region to deploy resources into."
  type        = string
  default     = "eu-west-1"
}

variable "environment" {
  description = "Deployment stage (dev, tst, acc, prd). Used in names and tags."
  type        = string
  default     = "sandbox"
}

variable "delimiter" {
  description = "Character used to join the parts of a resource name."
  type        = string
  default     = "-"
}

variable "s3_buckets" {
  description = "List of S3 buckets to create. Each needs a unique 'key'; 'tags' are optional."
  type = list(object({
    key  = string
    tags = optional(map(string), {})
  }))
  default = []
}

variable "ecr_repositories" {
  description = "List of ECR repositories to create. Each holds the Docker images for one app."
  type = list(object({
    key                  = string
    image_tag_mutability = optional(string, "MUTABLE")
    image_scanning_configuration = optional(object({
      scan_on_push = bool
    }), { scan_on_push = true })
    tags = optional(map(string), {})
  }))
  default = []
}

variable "apprunner_services" {
  description = "List of App Runner services to deploy. Each runs one container image pulled from ECR."
  type = list(object({
    key = string
    source_configuration = object({
      image_repository = object({
        image_identifier      = string
        image_repository_type = string
        image_configuration = object({
          port = number
        })
      })
      auto_deployments_enabled = bool
    })
    tags = optional(map(string), {})
  }))
  default = []
}
