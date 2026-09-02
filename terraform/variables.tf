variable "project_name" {
  description = "Project prefix applied to every resource name"
  type        = string
  default     = "fintech"
}

variable "environment" {
  description = "Environment name (dev/staging/prod) - one code path, values differ per tfvars"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.20.0.0/16"
}

variable "container_port" {
  description = "Port the auth-service listens on"
  type        = number
  default     = 3001
}

variable "db_name" {
  description = "Postgres database name"
  type        = string
  default     = "fintech"
}

variable "db_username" {
  description = "Postgres master username"
  type        = string
  default     = "fintech_user"
}

variable "alert_email" {
  description = "E-mail address for CloudWatch alarm notifications (empty = no subscription)"
  type        = string
  default     = ""
}
