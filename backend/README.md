# Backend Module

This Terraform module provisions a scalable serverless backend using:

- AWS Lambda (multiple functions)
- Amazon API Gateway (HTTP API v2)
- IAM role for Lambda execution

This is the first tagged version of the backend module and establishes the foundation for an extensible, multi-function architecture.

---

## Architecture Overview

This module dynamically provisions:

- One HTTP API
- One stage per environment
- One integration per Lambda function
- One route per Lambda function
- One Lambda permission per function

Each Lambda function is defined declaratively via the `lambdas` input variable.

The architecture follows this flow:

```
Route (METHOD /path)
→ API Gateway HTTP API
→ Lambda Proxy Integration
→ Lambda Function
```

---

## Why HTTP API (v2)?

This module uses HTTP API instead of REST API because:

- Lower latency
- Lower cost
- Simpler deployment model
- Automatic stage deployment (`auto_deploy = true`)
- No manual deployment triggers or hashing logic required

REST APIs and OpenAPI definitions were intentionally avoided to:

- Remove redeployment complexity
- Avoid YAML templating and ARN injection
- Keep infrastructure fully Terraform-native
- Improve scalability when adding new Lambda functions

---

## Module Inputs

### `environment`

The deployment environment name (e.g., `dev`, `prod`).

Used for:
- Lambda function naming
- API stage naming

---

### `artifacts_bucket_name`

The S3 bucket that stores Lambda deployment artifacts.

Each Lambda artifact is expected at:

```
lambda/<lambda_key>/<artifact_key>
```

Example:

```
lambda/settlements/artifact-sha-f7f8598a.zip
lambda/image_processor/image-processor.1.0.0.zip
```

---

### `lambdas`

Defines all Lambda functions to provision.

Type:

```hcl
map(object({
  handler            = string
  runtime            = string
  artifact_key       = string
  route_key          = string
  memory_size        = optional(number, 512)
  timeout            = optional(number, 30)
  integration_method = optional(string, "GET")
}))
```

**Route Definition Format**

Routes use HTTP API route syntax:

```
<METHOD> /<PATH>
```

Examples:
- `GET /images`
- `POST /process`
- `GET /images/{id}`
- `ANY /health`

Each Lambda function defines exactly one route.

This ensures:
- Clear ownership of endpoints
- Easy expansion
- Minimal coupling
- Clean scaling from 1 → N functions

---

## Example Usage (Environment Layer)

```hcl
module "backend" {
  source = "../../modules/backend"

  environment           = "dev"
  artifacts_bucket_name = var.artifacts_bucket_name

  lambdas = {
    image_processor = {
      handler      = "app.handler.handler"
      runtime      = "python3.10"
      artifact_key = "image-processor.1.0.0.zip"
      route_key    = "POST /process-image"
    }

    list_images = {
      handler      = "app.list.handler"
      runtime      = "python3.10"
      artifact_key = "list-images.1.0.0.zip"
      route_key    = "GET /images"
    }
  }
}
```

To add a new Lambda function:
1. Upload its artifact to S3
2. Add a new entry to the `lambdas` map
3. Run `terraform apply`

No additional API configuration is required.

---

## Best Practices Followed

- Stateless, environment-agnostic module design
- No hardcoded Lambda assumptions
- Fully dynamic multi-function provisioning
- Least coupling between API and Lambda definitions
- HTTP API auto-deployment
- Scalable route-to-function mapping
- Clean artifact versioning via S3

---

## Tradeoffs vs OpenAPI

This module intentionally avoids OpenAPI specification files.

**Tradeoffs:**

| Benefits | Tradeoff |
|----------|----------|
| Simpler infrastructure code | API schema is not centrally defined in a spec file |
| No ARN injection into YAML templates | Documentation generation must be handled separately if needed |
| No redeployment hashing | |
| Easier to reason about in Terraform | |

This approach prioritizes infrastructure scalability and maintainability over spec-driven API management.

---

## Future Extensions

This module can be extended to support:

- JWT authorizers
- Custom domains
- CORS configuration
- Access logging
- Rate limiting
- Multiple routes per Lambda
- Additional environment variables
- VPC-enabled Lambdas

The current structure supports these extensions without architectural changes.

---

## Summary

This backend module provides a clean, scalable serverless foundation.

Adding a new Lambda requires only:
- Uploading a new artifact
- Defining its configuration in `lambdas`

No API restructuring is necessary.

This enables contributors to introduce new backend functionality with minimal infrastructure friction.