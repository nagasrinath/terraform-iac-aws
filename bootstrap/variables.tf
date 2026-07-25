variable "region" {
  type    = string
  default = "us-east-1"
}

variable "state_bucket_name" {
  description = "Leave null to default to tf-state-<account-id> (globally unique, no bikeshedding required)"
  type        = string
  default     = null
}

variable "lock_table_name" {
  type    = string
  default = "tf-locks"
}
