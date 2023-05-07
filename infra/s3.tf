# ---------------------------------------------------------------
#                   Frontend
# ---------------------------------------------------------------

resource "aws_s3_bucket" "frontend_bucket" {
  bucket = "${var.prefix}-${var.frontend_bucket_name}"
}

data "aws_iam_policy_document" "frontend_bucket_policy_document" {
  statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.frontend_bucket.arn]
    principals {
      identifiers = [aws_cloudfront_origin_access_identity.frontend_s3_distribution.iam_arn]
      type        = "AWS"
    }
    sid = "bucket_policy_site_root"
  }
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.frontend_bucket.arn}/*"]
    principals {
      identifiers = [aws_cloudfront_origin_access_identity.frontend_s3_distribution.iam_arn]
      type        = "AWS"
    }
    sid = "bucket_policy_site_all"
  }
}

resource "aws_s3_bucket_policy" "frontend_bucket_policy" {
  depends_on = [aws_cloudfront_origin_access_identity.frontend_s3_distribution]
  bucket     = aws_s3_bucket.frontend_bucket.id
  policy     = data.aws_iam_policy_document.frontend_bucket_policy_document.json
}

resource "aws_s3_bucket_public_access_block" "frontend_bucket_block_public_access" {
  bucket                  = aws_s3_bucket.frontend_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ---------------------------------------------------------------
#                           CDN
# ---------------------------------------------------------------

resource "aws_s3_bucket" "cdn" {
  bucket = "${var.prefix}-${var.cdn_bucket_name}"
}

data "aws_iam_policy_document" "cdn_bucket_policy_document" {
  statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.cdn.arn]
    principals {
      identifiers = [aws_cloudfront_origin_access_identity.cdn_s3_distribution.iam_arn]
      type        = "AWS"
    }
    sid = "bucket_policy_site_root"
  }
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.cdn.arn}/*"]
    principals {
      identifiers = [aws_cloudfront_origin_access_identity.cdn_s3_distribution.iam_arn]
      type        = "AWS"
    }
    sid = "bucket_policy_site_all"
  }
}

resource "aws_s3_bucket_policy" "cdn_bucket_policy" {
  depends_on = [aws_cloudfront_origin_access_identity.cdn_s3_distribution]
  bucket     = aws_s3_bucket.cdn.id
  policy     = data.aws_iam_policy_document.cdn_bucket_policy_document.json
}

resource "aws_s3_bucket_cors_configuration" "cdn_cors" {
  bucket = aws_s3_bucket.cdn.bucket

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["*"]
    expose_headers  = []
  }
}
