# WSEM Terraform Modules

Reusable, version-controlled Terraform modules for the **West Bank Settlements Expansion Monitor (WSEM)** project.

This repository contains production-grade infrastructure modules designed to be:
- **Environment-agnostic**: Work across dev, staging, and prod
- **Composable**: Modules work together seamlessly
- **Scalable**: Built to grow from MVP to full production
- **Contributor-friendly**: Clear interfaces and documentation

---

## Repository Structure

```
.
├── backend/          # Serverless backend infrastructure
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── README.md
├── frontend/         # Static hosting and CDN infrastructure
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── README.md
└── README.md         # This file
```

---

## Modules Overview

### [Backend Module](./backend/)

Provisions a scalable serverless backend using AWS Lambda and API Gateway (HTTP API v2).

**Features:**
- Dynamic multi-function Lambda provisioning
- HTTP API with automatic stage deployment
- Route-based Lambda integration
- S3-backed artifact versioning
- IAM roles with least-privilege access

**Use case:** RESTful API endpoints backed by Lambda functions

**Example:**
```hcl
module "backend" {
  source = "git::ssh://git@github.com/wsem/terraform-modules.git//backend?ref=v0.1.0"

  environment           = "dev"
  artifacts_bucket_name = "wsem-artifacts-dev"

  lambdas = {
    settlements = {
      handler      = "app.handler"
      runtime      = "python3.10"
      artifact_key = "settlements.1.0.0.zip"
      route_key    = "GET /settlements"
    }
  }
}
```

[📖 Full Backend Documentation →](./backend/README.md)

---

### [Frontend Module](./frontend/)

Provisions static hosting and global CDN with seamless API integration.

**Features:**
- Private S3 bucket for static assets
- CloudFront distribution with dual origins
- Unified domain for frontend + API (no CORS)
- Optimized caching strategies
- Origin Access Control (OAC) security

**Use case:** Hosting SPAs with integrated backend API routing

**Example:**
```hcl
module "frontend" {
  source = "git::ssh://git@github.com/wsem/terraform-modules.git//frontend?ref=v0.1.0"

  environment             = "dev"
  api_gateway_domain_name = module.backend.api_gateway_domain_name
}
```

[📖 Full Frontend Documentation →](./frontend/README.md)

---

## Architecture Philosophy

### Separation of Concerns

These modules follow a clear architectural separation:

```
┌─────────────────────────────────────────────────────────┐
│                    CloudFront (CDN)                     │
│                                                         │
│  ┌─────────────────┐         ┌────────────────────┐   │
│  │   / (default)   │         │    /api/* (proxy)  │   │
│  └────────┬────────┘         └──────────┬─────────┘   │
└───────────┼───────────────────────────────┼───────────┘
            │                               │
            ▼                               ▼
    ┌───────────────┐            ┌──────────────────┐
    │  S3 Bucket    │            │  API Gateway     │
    │  (Frontend)   │            │  (Backend)       │
    └───────────────┘            └────────┬─────────┘
                                          │
                                          ▼
                                 ┌─────────────────┐
                                 │ Lambda Functions│
                                 │   ┌─────────┐   │
                                 │   │ Python  │   │
                                 │   │ Node.js │   │
                                 │   │   ...   │   │
                                 │   └─────────┘   │
                                 └─────────────────┘
```

**Benefits:**
- Frontend and backend can be deployed independently
- Modules can be versioned separately
- Clear ownership boundaries
- Easy to scale each layer independently

---

## Module Versioning Strategy

### Git Tags as Versions

This repository uses **Git tags** for module versioning.

**Format:** `v<major>.<minor>.<patch>`

**Examples:**
- `v0.1.0` — Initial MVP release
- `v0.2.0` — Added custom domain support
- `v1.0.0` — Production-ready release
- `v1.1.0` — New feature (backward compatible)
- `v1.1.1` — Bug fix

### Referencing Modules

**Specific version (recommended for production):**
```hcl
module "backend" {
  source = "git::ssh://git@github.com/wsem/terraform-modules.git//backend?ref=v0.1.0"
  # ...
}
```

**Latest from main (for development):**
```hcl
module "backend" {
  source = "git::ssh://git@github.com/wsem/terraform-modules.git//backend?ref=main"
  # ...
}
```

**Specific module at specific version:**
```hcl
module "frontend" {
  source = "git::ssh://git@github.com/wsem/terraform-modules.git//frontend?ref=v0.1.0"
  # ...
}
```

---

## Usage in Environment Layers

These modules are designed to be consumed by environment-specific Terraform configurations.

### Recommended Directory Structure

```
wsem-infrastructure/
├── modules/                    # This repository (as submodule or separate repo)
│   ├── backend/
│   └── frontend/
├── environments/
│   ├── dev/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── terraform.tfvars
│   ├── staging/
│   │   └── ...
│   └── prod/
│       └── ...
└── shared/
    └── artifacts-bucket/
```

### Example Environment Configuration

**File:** `environments/dev/main.tf`

```hcl
terraform {
  required_version = ">= 1.0"
  
  backend "s3" {
    bucket = "wsem-terraform-state"
    key    = "dev/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = "us-east-1"
}

# Backend module
module "backend" {
  source = "git::ssh://git@github.com/wsem/terraform-modules.git//backend?ref=v0.1.0"

  environment           = "dev"
  artifacts_bucket_name = var.artifacts_bucket_name

  lambdas = {
    settlements = {
      handler      = "app.handler"
      runtime      = "python3.10"
      artifact_key = "settlements.1.0.0.zip"
      route_key    = "GET /settlements"
    }
    
    timeline = {
      handler      = "index.handler"
      runtime      = "nodejs18.x"
      artifact_key = "timeline.1.0.0.zip"
      route_key    = "GET /timeline"
    }
  }
}

# Frontend module
module "frontend" {
  source = "git::ssh://git@github.com/wsem/terraform-modules.git//frontend?ref=v0.1.0"

  environment             = "dev"
  api_gateway_domain_name = module.backend.api_gateway_domain_name
}

# Outputs
output "api_url" {
  value       = module.backend.api_gateway_domain_name
  description = "Backend API base URL"
}

output "frontend_url" {
  value       = "https://${module.frontend.cloudfront_domain_name}"
  description = "Frontend CloudFront URL"
}

output "frontend_bucket" {
  value       = module.frontend.frontend_bucket_name
  description = "S3 bucket for frontend assets"
}
```

---

## Quick Start

### 1. Prerequisites

- Terraform >= 1.0
- AWS CLI configured with appropriate credentials
- S3 bucket for Lambda artifacts (e.g., `wsem-artifacts-dev`)

### 2. Create Environment Configuration

```bash
mkdir -p environments/dev
cd environments/dev
```

Create `main.tf` using the example above.

### 3. Initialize Terraform

```bash
terraform init
```

### 4. Review Plan

```bash
terraform plan
```

### 5. Deploy Infrastructure

```bash
terraform apply
```

### 6. Retrieve Outputs

```bash
# Get API URL
terraform output -raw api_url

# Get Frontend URL
terraform output -raw frontend_url

# Get Frontend S3 Bucket
terraform output -raw frontend_bucket
```

### 7. Deploy Application Code

```bash
# Deploy frontend assets
aws s3 sync ./frontend/dist/ s3://$(terraform output -raw frontend_bucket)/ --delete

# Invalidate CloudFront cache
aws cloudfront create-invalidation \
  --distribution-id $(terraform output -raw cloudfront_distribution_id) \
  --paths "/*"
```

---

## Module Inputs and Outputs

### Backend Module

**Inputs:**
- `environment` (string, required): Environment name
- `artifacts_bucket_name` (string, required): S3 bucket containing Lambda zips
- `lambdas` (map(object), required): Lambda function configurations

**Outputs:**
- `api_gateway_domain_name`: API Gateway domain for frontend integration
- `lambda_function_names`: Map of Lambda function names
- `api_gateway_id`: API Gateway ID

[See full backend documentation →](./backend/README.md)

---

### Frontend Module

**Inputs:**
- `environment` (string, required): Environment name
- `api_gateway_domain_name` (string, required): Backend API domain

**Outputs:**
- `frontend_bucket_name`: S3 bucket name for frontend assets
- `cloudfront_distribution_id`: CloudFront distribution ID
- `cloudfront_domain_name`: CloudFront domain name

[See full frontend documentation →](./frontend/README.md)

---

## Contributing to Modules

### Module Design Principles

When contributing to or extending these modules:

1. **Keep modules environment-agnostic**
   - No hardcoded environment names
   - Use variables for all environment-specific values

2. **Maintain backward compatibility**
   - Use `optional()` for new variables when possible
   - Document breaking changes clearly

3. **Follow least-privilege IAM**
   - Grant only necessary permissions
   - Use resource-based policies when appropriate

4. **Enable extensibility**
   - Design for future features without breaking existing usage
   - Use dynamic blocks and `for_each` for scalability

5. **Document everything**
   - Update README.md for any interface changes
   - Add inline comments for complex logic
   - Provide usage examples

### Development Workflow

1. **Create feature branch**
   ```bash
   git checkout -b feature/add-custom-domain-support
   ```

2. **Make changes and test**
   ```bash
   cd environments/dev
   terraform plan
   terraform apply
   ```

3. **Update documentation**
   - Module README
   - Root README (if necessary)
   - CHANGELOG (if exists)

4. **Open pull request**
   - Clear description of changes
   - Tag as breaking/non-breaking
   - Include test results

5. **Tag new version after merge**
   ```bash
   git tag -a v0.2.0 -m "Add custom domain support"
   git push origin v0.2.0
   ```

---

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Deploy Infrastructure

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  terraform:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: 1.5.0
      
      - name: Terraform Init
        run: terraform init
        working-directory: ./environments/dev
      
      - name: Terraform Plan
        run: terraform plan
        working-directory: ./environments/dev
      
      - name: Terraform Apply
        if: github.ref == 'refs/heads/main'
        run: terraform apply -auto-approve
        working-directory: ./environments/dev
```

---

## Roadmap

### Current Features (v0.1.0)
- ✅ Multi-Lambda backend provisioning
- ✅ HTTP API Gateway integration
- ✅ CloudFront + S3 frontend hosting
- ✅ Dual-origin architecture (frontend + API)
- ✅ Environment isolation

### Planned Features (v0.2.0)
- 🔄 Custom domain support (ACM + Route53)
- 🔄 CloudFront Functions for SPA routing
- 🔄 WAF integration for security
- 🔄 Enhanced IAM scoping
- 🔄 CloudWatch Logs and alarms

### Future Considerations (v1.0.0+)
- 📋 DynamoDB module for data layer
- 📋 VPC-enabled Lambda support
- 📋 Multi-region deployment
- 📋 Blue-green deployment patterns
- 📋 Lambda@Edge for advanced routing

---

## Best Practices

### State Management

**Use remote state:**
```hcl
terraform {
  backend "s3" {
    bucket = "wsem-terraform-state"
    key    = "env/dev/terraform.tfstate"
    region = "us-east-1"
  }
}
```

**Enable state locking:**
- Use DynamoDB table for state locking
- Prevents concurrent modifications
- Recommended for team environments

### Secret Management

**Never commit secrets to version control.**

Use AWS Systems Manager Parameter Store or Secrets Manager:

```hcl
data "aws_ssm_parameter" "api_key" {
  name = "/wsem/dev/api_key"
}
```

### Cost Optimization

- Tag all resources with `Environment` and `Project`
- Use CloudWatch to monitor Lambda execution time
- Review CloudFront cache hit ratios
- Set S3 lifecycle policies for old artifacts

---

## Troubleshooting

### Common Issues

**Issue:** `Error: Module not found`

**Solution:** Verify Git repository access and ref exists:
```bash
git ls-remote --tags git@github.com:wsem/terraform-modules.git
```

---

**Issue:** `Error: Backend configuration changed`

**Solution:** Reinitialize Terraform:
```bash
terraform init -reconfigure
```

---

**Issue:** Module changes not reflected

**Solution:** Update module source to latest version or run:
```bash
terraform get -update
```

---

## Support and Documentation

- **Backend Module Docs**: [./backend/README.md](./backend/README.md)
- **Frontend Module Docs**: [./frontend/README.md](./frontend/README.md)
- **Issues**: [GitHub Issues](https://github.com/wsem/terraform-modules/issues)
- **Discussions**: [GitHub Discussions](https://github.com/wsem/terraform-modules/discussions)

---

## License

[Add your license here]

---

## Maintainers

- **Noha Amr** — Project Owner
- **Sami Hajji** — Infrastructure Lead
- **Abdelali Zakaria** — Backend Lead

---

**You've officially created a modular, scalable, production-grade infrastructure foundation.**

These modules transform infrastructure from "one-off scripts" to "reusable, versioned components."

Now the real question:

Do you want to next:

- Create a shared artifacts bucket module?
- Add DynamoDB module for data layer?
- Build CI/CD pipelines for module testing?
- Or set up automated documentation generation?

We're building infrastructure that grows with the project.
