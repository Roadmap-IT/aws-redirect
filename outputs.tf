output "s3_bucket_website_endpoint" {
  description = "The domain of the website endpoint, if the bucket is configured with a website. If not, this will be an empty string. This is used to create Route 53 alias records. "
  value       = aws_s3_bucket.redirect.website_endpoint
}
output "s3_bucket_website_domain" {
  description = "The domain of the website endpoint, if the bucket is configured with a website. If not, this will be an empty string. This is used to create Route 53 alias records. "
  value       = aws_s3_bucket.redirect.website_domain
}
output "cf_domain_name" {
  value       = aws_cloudfront_distribution.cf_home_redirect.domain_name
  description = "Domain name corresponding to the distribution"
}