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
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
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
        Resource = "arn:aws:sns:eu-west-1:730335226605:websiteMessagesTopic"
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_logging" {
  name        = "lambda_logging"
  description = "IAM policy for logging from a lambda"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_sns_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/lambdafunc.zip"
}

resource "aws_lambda_function" "send_message" {
  function_name    = "sendMessageFunction"
  role            = aws_iam_role.lambda_role.arn
  handler         = "lambda_function.lambda_handler"
  runtime         = "python3.8"
  filename        = data.archive_file.lambda_zip.output_path
 
  environment {
    variables = {
      SNS_TOPIC_ARN = "arn:aws:sns:eu-west-1:730335226605:websiteMessagesTopic"
    }
  }
 
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.send_message.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}

resource "aws_apigatewayv2_api" "api" {
  name          = "WebsiteMessagesAPI"
  protocol_type = "HTTP"
  cors_configuration {
    allow_headers     = ["Content-Type", "X-Amz-Date", "Authorization", "X-Api-Key", "X-Amz-Security-Token"]
    allow_methods     = ["POST", "OPTIONS"]
    allow_origins     = ["http://romanstripa.ie.s3-website-eu-west-1.amazonaws.com"]
    allow_credentials = true
    max_age           = 300
  }
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id                  = aws_apigatewayv2_api.api.id
  integration_type        = "AWS_PROXY"
  integration_uri         = aws_lambda_function.send_message.invoke_arn
  integration_method      = "POST"
  payload_format_version  = "2.0"
}

resource "aws_apigatewayv2_route" "post_route" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "POST /send-message"
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
