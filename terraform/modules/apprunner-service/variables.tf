# Inputs this module accepts from whoever calls it.
variable "name" {
  description = "Name of the App Runner service."
  type        = string
}

variable "source_configuration" {
  description = "Where the service gets its image (ECR repo + type + port) and whether to auto-deploy on new pushes."
  type = object({
    image_repository = object({
      image_identifier      = string
      image_repository_type = string
      image_configuration = object({
        port = number
      })
    })
    auto_deployments_enabled = bool
  })
}

variable "tags" {
  description = "Map of tags to attach to the service."
  type        = map(string)
}
