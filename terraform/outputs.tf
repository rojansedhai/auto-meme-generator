output "api_endpoint" {
  description = "Paste this URL into the API_BASE_URL constant in src/frontend/index.html"
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "cloudfront_url" {
  description = "Access your secure web app here"
  value       = "https://${aws_cloudfront_distribution.frontend_cf.domain_name}"
}

output "frontend_bucket" {
  description = "Upload src/frontend/index.html to this bucket"
  value       = aws_s3_bucket.frontend.id
}
