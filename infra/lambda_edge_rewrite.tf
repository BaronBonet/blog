locals {
  zipped_code = "${path.module}/lambda_edge_rewrite/lambda_edge_rewrite.zip"
}
resource "aws_lambda_function" "rewrite" {
  provider = aws.us-east-1
  function_name    = "RewriteURL"
  handler          = "lambda_edge_rewrite.lambda_handler"
  runtime          = "python3.8"
  role             = aws_iam_role.lambda_edge.arn
  filename         = local.zipped_code
  source_code_hash = filebase64sha256( local.zipped_code)

  publish = true
}

resource "aws_iam_role" "lambda_edge" {
  name = "lambda_edge"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "edgelambda.amazonaws.com"
        }
      }
    ]
  })


}

resource "aws_iam_role_policy" "lambda_edge_s3_and_cloudfront" {
  name = "lambda_edge_s3_and_cloudfront"
  role = aws_iam_role.lambda_edge.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Effect   = "Allow"
        Resource = [
          aws_s3_bucket.frontend_bucket.arn,
          "${aws_s3_bucket.frontend_bucket.arn}/*"
        ]
      },
      {
        Action = [
          "cloudfront:UpdateDistribution"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_lambda_permission" "allow_cloudfront" {
  statement_id  = "AllowExecutionFromCloudFront"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.rewrite.function_name
  principal     = "edgelambda.amazonaws.com"
  source_arn    = aws_cloudfront_distribution.frontend_distribution.arn
}
