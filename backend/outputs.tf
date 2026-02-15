output "api_gateway_domain_name" {
  value = trimprefix(
    aws_apigatewayv2_api.http_api.api_endpoint,
    "https://"
  )
}

# CloudFront origin.domain_name expectes no trailing slash, but API Gateway endpoint includes one. So, we need to remove it.
