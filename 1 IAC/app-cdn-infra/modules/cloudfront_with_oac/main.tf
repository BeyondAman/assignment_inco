resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "oac-${var.env}"
  description                       = "OAC for ${var.env}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "this" {
  enabled             = true
  is_ipv6_enabled     = true
  price_class         = "PriceClass_100"

  dynamic "origin" {
    for_each = var.origins
    content {
      domain_name              = origin.value.domain_name
      origin_id                = origin.key
      origin_path              = try(origin.value.origin_path, "")
      origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
    }
  }

  default_cache_behavior {
    target_origin_id       = var.path_behaviors[0].target_origin_id
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }
    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  dynamic "ordered_cache_behavior" {
    for_each = slice(var.path_behaviors, 1, length(var.path_behaviors))
    content {
      path_pattern           = ordered_cache_behavior.value.path_pattern
      target_origin_id       = ordered_cache_behavior.value.target_origin_id
      viewer_protocol_policy = "redirect-to-https"
      allowed_methods        = ["GET", "HEAD", "OPTIONS"]
      cached_methods         = ["GET", "HEAD"]
      compress               = true
      forwarded_values {
        query_string = false
        cookies { forward = "none" }
      }
      min_ttl     = 0
      default_ttl = 3600
      max_ttl     = 86400
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = var.acm_certificate_arn == "" ? true : false
    acm_certificate_arn            = var.acm_certificate_arn == "" ? null : var.acm_certificate_arn
    minimum_protocol_version       = "TLSv1.2_2021"
    ssl_support_method             = var.acm_certificate_arn == "" ? null : "sni-only"
  }

  restrictions { 
    geo_restriction { 
      restriction_type = "none" 
    } 
  }
  tags = var.tags

  web_acl_id = var.waf_web_acl_arn != "" ? var.waf_web_acl_arn : null
}

resource "aws_s3_bucket_policy" "origin_read" {
  for_each = var.origins
  bucket   = split(":::", each.value.s3_bucket_arn)[1] == null ? replace(each.value.s3_bucket_arn, "arn:aws:s3:::", "") : replace(each.value.s3_bucket_arn, "arn:aws:s3:::", "")
  policy   = data.aws_iam_policy_document.oac_read[each.key].json
}


data "aws_iam_policy_document" "oac_read" {
  for_each = var.origins

  statement {
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    actions = [
      "s3:GetObject"
    ]
    resources = [
      "${each.value.s3_bucket_arn}/*"
    ]
  }
}