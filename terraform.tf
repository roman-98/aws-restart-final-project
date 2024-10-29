resource "aws_s3_bucket" "website_bucket" {
  bucket = "romanstripa.ie"
}

resource "aws_s3_bucket_website_configuration" "website_config" {
  bucket = aws_s3_bucket.website_bucket.id

  index_document {
    suffix = "index.html"
  }

  depends_on = [aws_s3_bucket.website_bucket]
}

resource "aws_s3_bucket_public_access_block" "website_public_access_block" {
  bucket = aws_s3_bucket.website_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false

  depends_on = [aws_s3_bucket_website_configuration.website_config]
}

resource "aws_s3_bucket_policy" "website_policy" {
  bucket = aws_s3_bucket.website_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = [
          "s3:GetObject",
          "s3:DeleteObject"
        ]
        Resource  = "${aws_s3_bucket.website_bucket.arn}/*"
      }
    ]
  })

  depends_on = [
    aws_s3_bucket_public_access_block.website_public_access_block,
    aws_s3_bucket_website_configuration.website_config
  ]
}

output "website_url" {
  value = aws_s3_bucket.website_bucket.website_domain
}

resource "aws_sns_topic" "website_messages" {
  name = "websiteMessagesTopic"
}

resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.website_messages.arn
  protocol  = "email"
  endpoint  = "romanstripa@gmail.com"
}

resource "aws_iam_role" "lambda_role" {
  name = "lambda_sns_publish_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_sns_policy" {
  name        = "lambda_sns_publish_policy"
  description = "IAM policy for Lambda to publish messages to SNS"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = "sns:Publish",
        Resource = aws_sns_topic.website_messages.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_sns_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_sns_policy.arn
}

resource "aws_lambda_function" "send_message" {
  function_name = "sendMessageFunction"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.8"
  filename      = "function.zip" 

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.website_messages.arn
    }
  }

  source_code_hash = filebase64sha256("function.zip")
}
