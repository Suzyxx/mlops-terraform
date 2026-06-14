# Inputs this module accepts from whoever calls it.
variable "name" {
  description = "Name of the ECR repository."
  type        = string
}

variable "image_tag_mutability" {
  description = "MUTABLE (tags can be overwritten) or IMMUTABLE (tags are write-once)."
  type        = string
  default     = "MUTABLE"
}

variable "image_scanning_configuration" {
  description = "Vulnerability scanning settings; scan_on_push scans every pushed image."
  type = object({
    scan_on_push = bool
  })
  default = {
    scan_on_push = true
  }
}

variable "tags" {
  description = "Map of tags to attach to the repository."
  type        = map(string)
}
