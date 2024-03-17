########################################################################################################################
## CloudFront distribution
########################################################################################################################
resource "aws_cloudfront_distribution" "default" {
  comment         = "timemanagementapp CloudFront Distribution"
  enabled         = true
  is_ipv6_enabled = false
  web_acl_id = aws_wafv2_web_acl.WafWebAcl.arn
  aliases         = ["prod.${var.domain_name}"]

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    target_origin_id       = aws_lb.ecs_alb.name
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = true
      headers      = ["*"]

     cookies {
        forward = "all"
      }
    }
  }

  origin {
    domain_name = "alb.${var.domain_name}"
    origin_id   = aws_lb.ecs_alb.name

    custom_origin_config {
      origin_read_timeout      = 60
      origin_keepalive_timeout = 60
      http_port                = 80
      https_port               = 443
      origin_protocol_policy   = "https-only"
      origin_ssl_protocols     = [ "TLSv1", "TLSv1.1", "TLSv1.2", "SSLv3"]
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.cloudfront_certificate.arn
    cloudfront_default_certificate = true
    minimum_protocol_version = "TLSv1.2_2021"
    ssl_support_method       = "sni-only"
  }

  tags = {
    Name     = "timamanagementapp"
  }
  depends_on = [
    aws_wafv2_web_acl.WafWebAcl,
  ]

}

########################################################################################################################
## Point A record to CloudFront distribution
########################################################################################################################


resource "aws_route53_record" "service_record" {
  name    = "prod.${var.domain_name}"
  type    = "A"
  zone_id = var.zone_id

 alias {
    name                   = aws_cloudfront_distribution.default.domain_name
    zone_id                = aws_cloudfront_distribution.default.hosted_zone_id
    evaluate_target_health = false
  }
}
 
  