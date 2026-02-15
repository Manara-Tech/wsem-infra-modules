# Frontend Module

This Terraform module provisions the frontend infrastructure for the **WSEM** project using:

- Amazon S3 for static asset hosting
- Amazon CloudFront for global content delivery
- Origin Access Control (OAC) for secure S3 access
- Integrated API routing to backend services

This module establishes a secure, scalable, and performant frontend delivery architecture with seamless backend integration.

---

## Architecture Overview

This module provisions:

- One S3 bucket (private, versioned, encrypted)
- One CloudFront distribution with two origins:
  - **Frontend origin**: S3 bucket for static assets
  - **API origin**: API Gateway for backend requests
- Origin Access Control for secure S3 access
- Custom cache and origin request policies

The architecture follows this flow:

```
User Request
→ CloudFront Distribution
  ├─ / (default)          → S3 Bucket (frontend assets)
  └─ /api/* (API routes)  → API Gateway → Lambda Functions
```

---

## Why CloudFront with Dual Origins?

This module uses a single CloudFront distribution with two origins because:

- **Unified domain**: Frontend and API share the same domain (no CORS issues)
- **Simplified authentication**: No cross-domain cookie/header complexities
- **Cost efficiency**: Single distribution reduces CloudFront costs
- **Better UX**: Relative API paths in frontend code (`/api/...`)
- **Cache control**: Different caching strategies for assets vs API responses

This eliminates the need for:
- CORS configuration
- API domain hardcoding in frontend
- Complex cross-domain authentication flows
- Multiple SSL certificates

---

## Module Inputs

### `environment`

The deployment environment name (e.g., `dev`, `prod`).

Used for:
- S3 bucket naming: `wsem-frontend-${environment}`
- Resource tagging
- Environment-specific configurations

---

### `api_gateway_domain_name`

The API Gateway domain name from the backend module.

Format:
```
<api-id>.execute-api.<region>.amazonaws.com
```

Example:
```
abc123xyz.execute-api.us-east-1.amazonaws.com
```

This value is typically passed from the backend module output:

```hcl
api_gateway_domain_name = module.backend.api_gateway_domain_name
```

---

## CloudFront Behaviors

### Default Behavior (`/`)

Routes all non-API requests to the S3 frontend bucket.

**Configuration:**
- **Methods**: `GET`, `HEAD`
- **Caching**: AWS Managed Cache Policy (`Managed-CachingOptimized`)
- **Compression**: Enabled (gzip, brotli)
- **HTTPS**: `redirect-to-https`
- **Origin**: S3 bucket via OAC

**Use cases:**
- Serving HTML, CSS, JavaScript files
- Images, fonts, and static assets
- SPA routing (index.html fallback)

---

### API Behavior (`/api/*`)

Routes all API requests to API Gateway.

**Configuration:**
- **Methods**: `GET`, `POST`, `PUT`, `PATCH`, `DELETE`, `OPTIONS`
- **Caching**: Disabled (TTL = 0) for real-time responses
- **Compression**: Enabled for efficiency
- **HTTPS**: `redirect-to-https`
- **Origin**: API Gateway via custom origin

**Headers forwarded:**
- `Accept`
- `Content-Type`
- All cookies
- All query strings

**Use cases:**
- RESTful API calls
- Real-time data fetching
- POST/PUT/DELETE operations

---

## S3 Bucket Configuration

### Security Features

- **Public access**: Fully blocked
- **Access method**: CloudFront OAC only
- **Encryption**: AES-256 (SSE-S3)
- **Versioning**: Enabled
- **Bucket policy**: Grants CloudFront read access only

### Best Practices

- No public bucket URLs
- All access via HTTPS through CloudFront
- Versioning enables rollback capabilities
- Encryption at rest by default

---

## API Integration Pattern

### Frontend to API Communication

The frontend code uses **relative paths** to call APIs:

```javascript
// Example: Fetch settlements data
fetch("/api/settlements?year=2024", {
  method: "GET",
  headers: {
    "Accept": "application/json"
  }
})
  .then(res => res.json())
  .then(data => console.log(data));
```

**No hardcoded domains needed** — CloudFront handles routing automatically.

---

### Backend Route Mapping

Backend Lambda routes defined in the backend module are automatically accessible:

| Backend Route Key | CloudFront Path | Lambda Handler |
|-------------------|-----------------|----------------|
| `GET /settlements` | `/api/settlements` | `settlements` Lambda |
| `GET /timeline` | `/api/timeline` | `timeline` Lambda |

To add a new API endpoint:
1. Add Lambda to backend module
2. Frontend automatically routes `/api/<path>` to it
3. No CloudFront changes required

---

## Example Usage (Environment Layer)

```hcl
module "frontend" {
  source = "../../modules/frontend"

  environment             = "dev"
  api_gateway_domain_name = module.backend.api_gateway_domain_name
}
```

### Complete Stack Example

```hcl
# Backend module
module "backend" {
  source = "../../modules/backend"

  environment           = "dev"
  artifacts_bucket_name = var.artifacts_bucket_name

  lambdas = {
    settlements = {
      handler      = "app.handler"
      runtime      = "python3.10"
      artifact_key = "settlements.1.0.0.zip"
      route_key    = "GET /settlements"
    }
  }
}

# Frontend module
module "frontend" {
  source = "../../modules/frontend"

  environment             = "dev"
  api_gateway_domain_name = module.backend.api_gateway_domain_name
}
```

---

## Module Outputs

### `frontend_bucket_name`

The name of the S3 bucket hosting frontend assets.

**Usage:**
```bash
# Upload frontend assets
aws s3 sync ./dist/ s3://$(terraform output -raw frontend_bucket_name)/
```

---

### `cloudfront_distribution_id`

The CloudFront distribution ID.

**Usage:**
```bash
# Invalidate CloudFront cache after deployment
aws cloudfront create-invalidation \
  --distribution-id $(terraform output -raw cloudfront_distribution_id) \
  --paths "/*"
```

---

### `cloudfront_domain_name`

The CloudFront distribution domain name.

**Usage:**
```bash
# Access your frontend
echo "Frontend URL: https://$(terraform output -raw cloudfront_domain_name)"
```

---

## Deployment Workflow

### Initial Deployment

1. **Provision infrastructure**:
   ```bash
   terraform apply
   ```

2. **Build frontend assets**:
   ```bash
   npm run build  # or your build command
   ```

3. **Upload to S3**:
   ```bash
   aws s3 sync ./dist/ s3://wsem-frontend-dev/ --delete
   ```

4. **Invalidate CloudFront cache**:
   ```bash
   aws cloudfront create-invalidation \
     --distribution-id <distribution-id> \
     --paths "/*"
   ```

5. **Access frontend**:
   ```
   https://<cloudfront-domain>.cloudfront.net
   ```

---

### CI/CD Integration

Example GitHub Actions workflow:

```yaml
- name: Deploy to S3
  run: |
    aws s3 sync ./dist/ s3://${{ secrets.FRONTEND_BUCKET_NAME }}/ --delete

- name: Invalidate CloudFront
  run: |
    aws cloudfront create-invalidation \
      --distribution-id ${{ secrets.CLOUDFRONT_DISTRIBUTION_ID }} \
      --paths "/*"
```

---

## Best Practices Implemented

- **Security**: Private S3 bucket with OAC-only access
- **Performance**: Optimized caching for assets, no caching for APIs
- **Cost efficiency**: Single CloudFront distribution for frontend + API
- **HTTPS enforcement**: All traffic redirected to HTTPS
- **Compression**: Enabled for faster downloads
- **Versioning**: S3 versioning for rollback capability
- **Encryption**: AES-256 encryption at rest
- **Environment isolation**: Tagged resources per environment

---

## Cache Behavior Details

### Frontend Assets (Default)

- **Cache Duration**: Managed by CloudFront (typically 24 hours)
- **Cache Key**: URL path only
- **Best for**: HTML, CSS, JS, images, fonts
- **Compression**: gzip, brotli

**Tip**: Use cache-busting filenames (e.g., `app.a7f9d3.js`) for immutable assets.

---

### API Responses (`/api/*`)

- **Cache Duration**: 0 (no caching)
- **Cache Key**: URL path + all query strings + headers
- **Best for**: Dynamic API responses
- **Compression**: Enabled

**Rationale**: API responses must be real-time; caching would serve stale data.

---

## Custom Domain Setup (Future Extension)

To use a custom domain (e.g., `wsem.example.com`):

1. **Request ACM certificate** in `us-east-1` (CloudFront requirement)
2. **Add to module**:
   ```hcl
   aliases             = ["wsem.example.com"]
   acm_certificate_arn = var.acm_certificate_arn
   ```
3. **Update DNS** to point to CloudFront domain

---

## Troubleshooting

### Frontend shows 403 Forbidden

**Cause**: CloudFront can't access S3 bucket.

**Solution**:
- Verify OAC is attached to origin
- Check S3 bucket policy allows CloudFront principal
- Ensure assets exist in S3

---

### API calls return 404

**Cause**: API Gateway domain name is incorrect.

**Solution**:
- Verify `api_gateway_domain_name` matches backend output
- Check API Gateway stage is deployed
- Confirm backend Lambda routes match frontend paths

---

### CloudFront serves old content

**Cause**: Cache hasn't been invalidated.

**Solution**:
```bash
aws cloudfront create-invalidation \
  --distribution-id <dist-id> \
  --paths "/*"
```

---

## Future Extensions

This module can be extended to support:

- Custom domain names with ACM certificates
- WAF (Web Application Firewall) integration
- CloudFront Functions for URL rewrites
- CloudFront access logs to S3
- Geo-restriction policies
- Response header policies (security headers)
- Lambda@Edge for advanced routing
- Multiple CloudFront origins (e.g., staging API)

The current structure supports these extensions without major refactoring.

---

## Summary

This frontend module provides a production-ready static hosting solution with seamless API integration.

**Key benefits:**
- Single domain for frontend + API (no CORS)
- Secure S3 access via OAC
- Optimized caching strategies
- Easy deployment via S3 sync
- Automatic API routing

**Adding new features requires only:**
- Uploading new frontend assets to S3
- Invalidating CloudFront cache
- Backend API changes are automatically routed

This enables contributors to iterate on the frontend without infrastructure changes.

---

**You've officially moved from "static hosting" to "unified frontend + API delivery platform."**

Now the real question:

Do you want to next:

- Add custom domain support with ACM?
- Implement CloudFront Functions for SPA routing?
- Set up CI/CD pipelines for automated deployments?
- Or add CloudFront access logging and monitoring?

We're building something that can actually scale.
