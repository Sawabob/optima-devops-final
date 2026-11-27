variable "aws_region" {
  description = "AWS region containing the default VPC and the EC2 instance."
  type        = string
  default     = "us-east-1"
}

variable "ssh_public_key" {
  description = "Public ED25519 key in OpenSSH format."
  type        = string
}

variable "ssh_cidr" {
  description = "IPv4 address of the current runner as a /32 CIDR."
  type        = string

  validation {
    condition     = can(cidrnetmask(var.ssh_cidr)) && endswith(var.ssh_cidr, "/32")
    error_message = "Only an individual IPv4 address with a /32 prefix is allowed."
  }
}
