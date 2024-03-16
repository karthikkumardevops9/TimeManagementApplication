########################################################################################################################
## Certificate for CloudFront Distribution in region us.east-1
########################################################################################################################


resource "aws_acm_certificate" "cloudfront_certificate" {
  domain_name               = "prod.${var.domain_name}"
  validation_method         = "DNS"
#   subject_alternative_names = ["*.${var.domain_name}"]


 tags = {
    Name = "timemanagement"
  }
}


resource "aws_acm_certificate_validation" "cloudfront_certificate" {
  certificate_arn         = aws_acm_certificate.cloudfront_certificate.arn
  validation_record_fqdns = [aws_route53_record.cloudfront_certificate_validation.fqdn]
}


########################################################################################################################
## We only need one record for the DNS validation for both certificates, as records are the same for all regions
########################################################################################################################
resource "aws_route53_record" "cloudfront_certificate_validation" {
  name    = tolist(aws_acm_certificate.cloudfront_certificate.domain_validation_options)[0].resource_record_name
  type    = tolist(aws_acm_certificate.cloudfront_certificate.domain_validation_options)[0].resource_record_type
  zone_id = var.zone_id
  records = [tolist(aws_acm_certificate.cloudfront_certificate.domain_validation_options)[0].resource_record_value]
  ttl     = 300
}

