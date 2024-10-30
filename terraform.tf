resource "aws_s3_bucket" "website_bucket" {
  bucket = "romanstripa.ie"
}

resource "aws_s3_bucket_website_configuration" "website_config" {
  bucket = aws_s3_bucket.website_bucket.id

  index_document {
    suffix = "index.html"
  }
}

resource "aws_s3_bucket_public_access_block" "website_public_access_block" {
  bucket                  = aws_s3_bucket.website_bucket.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "website_policy" {
  bucket = aws_s3_bucket.website_bucket.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = "*",
        Action    = "s3:GetObject",
        Resource  = "${aws_s3_bucket.website_bucket.arn}/*"
      }
    ]
  })
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

resource "aws_iam_policy" "lambda_s3_sns_policy" {
  name        = "lambda_s3_sns_policy"
  description = "IAM policy for Lambda to access S3 bucket and publish to SNS"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "sns:Publish"
        ],
        Resource = aws_sns_topic.website_messages.arn
      },
      {
        Effect   = "Allow",
        Action   = [
          "s3:GetObject",
          "s3:ListBucket"
        ],
        Resource = [
          "${aws_s3_bucket.website_bucket.arn}",
          "${aws_s3_bucket.website_bucket.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_s3_sns_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_s3_sns_policy.arn
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/sendEmailFunction.py" 
  output_path = "${path.module}/lambdaFunc.zip"
}

resource "aws_lambda_function" "send_message" {
  function_name = "sendMessageFunction"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.8"
  filename      = data.archive_file.lambda_zip.output_path

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.website_messages.arn
    }
  }

  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
}

resource "aws_lambda_permission" "s3_invoke" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.send_message.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.website_bucket.arn
}

resource "aws_s3_bucket_notification" "website_bucket_notification" {
  bucket = aws_s3_bucket.website_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.send_message.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "messages/" 
  }

  depends_on = [aws_lambda_function.send_message, aws_lambda_permission.s3_invoke]
}

resource "aws_lambda_function" "generate_presigned_url" {
  function_name = "GeneratePresignedUrlFunction"
  role          = aws_iam_role.lambda_role.arn
  handler       = "generate_presigned_url.lambda_handler"
  runtime       = "python3.8"
  filename      = data.archive_file.lambda_zip.output_path

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.website_bucket.bucket
    }
  }

  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
}

resource "aws_apigatewayv2_api" "api" {
  name          = "PresignedUrlAPI"
  protocol_type = "HTTP"

  cors_configuration {
    allow_headers     = ["Content-Type", "X-Amz-Date", "Authorization", "X-Api-Key", "X-Amz-Security-Token"]
    allow_methods     = ["GET", "OPTIONS"]
    allow_origins     = ["http://romanstripa.ie.s3-website-eu-west-1.amazonaws.com"]
    allow_credentials = false
  }
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id             = aws_apigatewayv2_api.api.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.generate_presigned_url.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "presign_route" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "GET /generate-presigned-url"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_stage" "default_stage" {
  api_id      = aws_apigatewayv2_api.api.id
  name        = "$default"
  auto_deploy = true
}

output "api_endpoint" {
  value = aws_apigatewayv2_stage.default_stage.invoke_url
}

output "website_url" {
  value       = aws_s3_bucket.website_bucket.website_endpoint
  description = "The URL of the hosted website"
}
