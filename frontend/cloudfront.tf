############################
# CloudFront Distribution
############################

resource "aws_cloudfront_distribution" "frontend_distribution" {

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CloudFront distribution for ${var.environment}"
  default_root_object = "index.html"

  ############################
  # Origins
  ############################

  # --- S3 Origin (Frontend) ---
  origin {
    domain_name              = aws_s3_bucket.frontend_bucket.bucket_regional_domain_name
    origin_id                = "s3-frontend-${var.environment}"
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend_oac.id
  }

  # --- API Gateway Origin ---
  origin {
    domain_name = var.api_gateway_domain_name
    origin_id   = "api-${var.environment}"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  ############################
  # Default Behavior (Frontend)
  ############################

  default_cache_behavior {
    target_origin_id       = "s3-frontend-${var.environment}"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]

    compress = true

    cache_policy_id = data.aws_cloudfront_cache_policy.caching_optimized.id
  }

  ############################
  # API Behavior
  ############################

  ordered_cache_behavior {
    path_pattern     = "/api/*"
    target_origin_id = "api-${var.environment}"

    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods  = ["GET", "HEAD"]

    compress = true

    cache_policy_id          = aws_cloudfront_cache_policy.api_no_cache.id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.api_all.id
  }

  ############################
  # Viewer Certificate
  ############################

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  ############################
  # Restrictions
  ############################

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = "WSEM"
  }
}

############################
# Origin Access Control
############################

resource "aws_cloudfront_origin_access_control" "frontend_oac" {
  name                              = "frontend-oac-${var.environment}"
  description                       = "OAC for frontend S3 bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

############################
# Default AWS Managed Cache Policy
############################

data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

############################
# API No-Cache Policy
############################

resource "aws_cloudfront_cache_policy" "api_no_cache" {
  name = "api-no-cache-${var.environment}"

  default_ttl = 0
  max_ttl     = 0
  min_ttl     = 0

  parameters_in_cache_key_and_forwarded_to_origin {
    enable_accept_encoding_gzip   = true
    enable_accept_encoding_brotli = true

    cookies_config {
      cookie_behavior = "none"
    }

    headers_config {
      header_behavior = "none"
    }

    query_strings_config {
      query_string_behavior = "none"
    }
  }
}

############################
# API Origin Request Policy
############################

resource "aws_cloudfront_origin_request_policy" "api_all" {
  name = "api-origin-request-${var.environment}"

  cookies_config {
    cookie_behavior = "all"
  }

  headers_config {
    header_behavior = "whitelist"
    headers {
      items = [
        "Accept",
        "Content-Type"
      ]
    }
  }

  query_strings_config {
    query_string_behavior = "all"
  }
}
