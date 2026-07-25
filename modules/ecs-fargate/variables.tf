variable "name" {
  description = "Name prefix for ECS resources"
  type        = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  description = "Subnets for the service's tasks (public, since there's no NAT for egress)"
  type        = list(string)
}

variable "container_image" {
  description = "Container image to run (defaults to a public demo image)"
  type        = string
  default     = "public.ecr.aws/nginx/nginx:latest"
}

variable "container_port" {
  type    = number
  default = 80
}

variable "cpu" {
  description = "Fargate task CPU units (256 = smallest)"
  type        = string
  default     = "256"
}

variable "memory" {
  description = "Fargate task memory in MB (512 = smallest paired with 256 CPU)"
  type        = string
  default     = "512"
}

variable "desired_count" {
  type    = number
  default = 1
}

variable "tags" {
  type    = map(string)
  default = {}
}
