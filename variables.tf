variable "instance-name" {
  default     = "locust"
  description = "GCP instance name"
}

variable "gcp-credentials" {
  sensitive = true
}

variable "gcp-project" {}

variable "instance-type" {
  default     = "e2-standard-2"
  description = "GCP instance type to create"
}

variable "region" {
  default = "us-central1"
}

variable "zone" {
  default = "us-central1-c"
}

variable "requests-per-second" {
  description = "Configure a cluster capable of generating this many RPS"
  type        = number
  default     = 1
}