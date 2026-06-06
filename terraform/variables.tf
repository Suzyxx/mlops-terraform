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
