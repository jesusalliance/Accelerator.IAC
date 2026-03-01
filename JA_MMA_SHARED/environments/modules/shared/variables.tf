variable "location" {
  type        = string
  description = "Azure region for all shared resources"
}

variable "rg_name" {
  type        = string
  description = "Name of the shared resource group"
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to all shared resources"
  default     = {}
}