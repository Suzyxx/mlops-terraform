# Inputs this module accepts from whoever calls it.
variable "bucket" {
  description = "(Optional, forces new resource) The name of the bucket. If omitted, AWS assigns a random unique name."
  type        = string
  default     = null
}

variable "tags" {
  description = "Map of tags to attach to the bucket."
  type        = map(string)
}
