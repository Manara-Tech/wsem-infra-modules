variable "environment" {
  description = "The deployment environment (e.g., dev, staging, prod)."
  type        = string
}

variable "artifact_key" {
  description = "S3 object key for the Lambda artifact"
  type        = string
}


variable "aws_region" {
  description = "The AWS region where the resources will be deployed."
  type        = string
  default     = "eu-west-1"
}

variable "artifacts_bucket_name" {
  description = "S3 bucket where Lambda artifacts are stored"
  type        = string
}

variable "lambdas" {
  type = map(object({
    handler            = string
    runtime            = string
    artifact_key       = string
    route_key          = string # HTTP API route format is <METHOD> /<PATH>, e.g., "GET /settlements{id}"
    memory_size        = optional(number, 512)
    timeout            = optional(number, 30)
    integration_method = optional(string, "GET")
  }))
}
