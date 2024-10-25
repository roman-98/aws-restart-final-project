provider "aws" {
  region = "eu-west-1"  
}

resource "aws_s3_bucket" "website_bucket" {
  bucket = "romanstripa.ie.guiub8398682jhf0s"
}

resource "aws_s3_bucket_website_configuration" "website_config" {
  bucket = aws_s3_bucket.website_bucket.id

  index_document {
    suffix = "index.html"
  }

  depends_on = [aws_s3_bucket.website_bucket]
}

resource "aws_s3_bucket_acl" "example" {
  bucket = aws_s3_bucket.website_bucket.id
  acl    = "public-read"

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
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.website_bucket.arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_acl.example]
}

output "website_url" {
  value = aws_s3_bucket.website_bucket.website_endpoint
}
