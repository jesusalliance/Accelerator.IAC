variable "location" {
  description = "Azure region"
  default     = "centralus"
  type        = string
}

variable "common_tags" {
  description = "Base tags"
  type        = map(string)
  default = {
    project     = "ja-mma-portal"
    cost-center = "ja-mma-portal"
    owner       = "ja-portal-team"
  }
}