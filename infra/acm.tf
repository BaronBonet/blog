
# ---------------------------------------------------------------------------------------
#                                   Frontend
# ---------------------------------------------------------------------------------------

resource "aws_acm_certificate" "blog_com" {
  provider                  = aws.us-east-1
  domain_name               = var.domain_name
  subject_alternative_names = ["www.${var.domain_name}"]
  validation_method         = "DNS"
  lifecycle {
    create_before_destroy = true
  }
}

data "aws_route53_zone" "blog_com" {
  name         = var.domain_name
  private_zone = false
}


resource "aws_route53_record" "blog_com" {
  for_each = {
    for dvo in aws_acm_certificate.blog_com.domain_validation_options : dvo.domain_name => {
      name    = dvo.resource_record_name
      record  = dvo.resource_record_value
      type    = dvo.resource_record_type
      zone_id = dvo.domain_name == var.domain_name ? data.aws_route53_zone.blog_com.zone_id : data.aws_route53_zone.blog_com.zone_id
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = each.value.zone_id
}

resource "aws_acm_certificate_validation" "blog_com" {
  provider                = aws.us-east-1
  certificate_arn         = aws_acm_certificate.blog_com.arn
  validation_record_fqdns = [for record in aws_route53_record.blog_com : record.fqdn]
}

# ---------------------------------------------------------------------------------------
#                                   CDN
# ---------------------------------------------------------------------------------------
resource "aws_acm_certificate" "blog_cdn" {
  provider                  = aws.us-east-1
  domain_name               = "cdn.${var.domain_name}"
  subject_alternative_names = ["www.cdn.${var.domain_name}"]
  validation_method         = "DNS"
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "blog_cdn" {
  for_each = {
    for dvo in aws_acm_certificate.blog_cdn.domain_validation_options : dvo.domain_name => {
      name    = dvo.resource_record_name
      record  = dvo.resource_record_value
      type    = dvo.resource_record_type
      zone_id = dvo.domain_name == var.domain_name ? data.aws_route53_zone.blog_com.zone_id : data.aws_route53_zone.blog_com.zone_id
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = each.value.zone_id
}

resource "aws_acm_certificate_validation" "blog_cdn" {
  provider                = aws.us-east-1
  certificate_arn         = aws_acm_certificate.blog_cdn.arn
  validation_record_fqdns = [for record in aws_route53_record.blog_cdn : record.fqdn]
}
