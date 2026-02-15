output "cloudfront_domain_name" {
  description = "The domain name of the CloudFront distribution"
  value       = aws_cloudfront_distribution.frontend_distribution.domain_name
}

output "cloudfront_distribution_id" {
  description = "The ID of the CloudFront distribution"
  value       = aws_cloudfront_distribution.frontend_distribution.id
}

output "frontend_bucket_name" {
  description = "The name of the S3 bucket hosting the frontend assets"
  value       = aws_s3_bucket.frontend_bucket.bucket
}
