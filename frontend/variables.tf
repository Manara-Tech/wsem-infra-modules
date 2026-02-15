variable "environment" {
  description = "The deployment environment (e.g., dev, staging, prod)."
  type        = string
}
variable "api_gateway_domain_name" {
  type        = string
  description = "Domain name of the backend API Gateway"
}
