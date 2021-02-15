terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 2.70"
    }
  }
}

variable "region" {
  default = "us-east-1"
}
variable "tag" {
  default = "redirect"
}
variable "domain" {
  type    = string
  default = "home.rankin.co.uk"
}
variable "url" {
  type    = string
  default = "https://console.jumpcloud.com"
}
# variable "cert" {
#   default = "f8b33b56-ef1c-430a-824a-d1d78f282069"
# }
# Find a certificate that is issued
data "aws_acm_certificate" "cert" {
  domain   = "*.rankin.co.uk"
  types    = ["IMPORTED"]
  statuses = ["ISSUED"]
}

data "aws_s3_bucket" "endpoint" {
  bucket = var.domain
}

provider "aws" {
  profile = "default"
  region  = var.region
}


# S3 bucket resource
resource "aws_s3_bucket" "redirect" {
  bucket = var.domain
  acl    = "public-read"
  policy = file("bucket_policy.json")

  website {
    redirect_all_requests_to = var.url
  }

  lifecycle_rule {
    prefix  = "logs/"
    enabled = true
    transition {
      days          = 1
      storage_class = "GLACIER"
    }
  }

  tags = {
    Name = var.tag
  }

}
# bucket policy - public read

# cloudfront


# locals {
#   s3_origin_id = aws_s3_bucket.redirect.id
# }

resource "aws_cloudfront_distribution" "cf_home_redirect" {
  depends_on = [
    aws_s3_bucket.redirect
  ]
  origin {
    # domain_name = aws_s3_bucket.redirect.website_endpoint
    domain_name = aws_s3_bucket.redirect.website_endpoint
    origin_id   = aws_s3_bucket.redirect.id
    custom_origin_config {
      http_port              = "80"
      https_port             = "443"
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1", "TLSv1.1", "TLSv1.2"]
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Terraform"
  default_root_object = "index.html"

  logging_config {
    include_cookies = false
    bucket          = aws_s3_bucket.redirect.bucket_domain_name
    # bucket          = var.domain.s3.amazonaws.com
  }

  #   aliases = ["mysite.example.com", "yoursite.example.com"]

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = aws_s3_bucket.redirect.id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  # Cache behavior with precedence 0
  ordered_cache_behavior {
    path_pattern     = "/content/immutable/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = aws_s3_bucket.redirect.id

    forwarded_values {
      query_string = false
      headers      = ["Origin"]

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  # Cache behavior with precedence 1
  ordered_cache_behavior {
    path_pattern     = "/content/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = aws_s3_bucket.redirect.id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  price_class = "PriceClass_200"

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["US", "CA", "GB", "DE"]
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = false
    ssl_support_method             = "sni-only"
    acm_certificate_arn            = data.aws_acm_certificate.cert.arn
  }

  tags = {
    Name = var.tag
  }
}


# SSL certificate

