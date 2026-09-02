variable "project_name" { type = string }
variable "environment" { type = string }
variable "db_name" { type = string }
variable "db_username" { type = string }
variable "subnet_ids" { type = list(string) }
variable "security_group_id" { type = string }
