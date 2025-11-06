resource "aws_acm_certificate" "cert" {
  domain_name = "api.example.com"
  validation_method = "DNS"
}
resource "aws_route53_record" "cert" {
  zone_id = "Z0000000000000"
  name    = tolist(aws_acm_certificate.cert.domain_validation_options)[0].resource_record_name
  type    = tolist(aws_acm_certificate.cert.domain_validation_options)[0].resource_record_type
  records = [tolist(aws_acm_certificate.cert.domain_validation_options)[0].resource_record_value]
  ttl     = 60
}
resource "aws_acm_certificate_validation" "validated" {
  certificate_arn = aws_acm_certificate.cert.arn
  validation_record_fqdns = [aws_route53_record.cert.fqdn]
}
