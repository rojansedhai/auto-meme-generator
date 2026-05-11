provider "aws" {
  region = var.aws_region
}

resource "random_id" "suffix" {
  byte_length = 2
}

resource "aws_s3_bucket" "input" {
  bucket        = "meme-input-${random_id.suffix.hex}"
  force_destroy = true
}

resource "aws_s3_bucket" "output" {
  bucket        = "meme-output-${random_id.suffix.hex}"
  force_destroy = true
}

# Explicit block for the Input Bucket
resource "aws_s3_bucket_public_access_block" "input_block" {
  bucket = aws_s3_bucket.input.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Explicit block for the Output Bucket
resource "aws_s3_bucket_public_access_block" "output_block" {
  bucket = aws_s3_bucket.output.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "registry" {
  name         = "MemeRegistry"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "MemeId"

  attribute {
    name = "MemeId"
    type = "S"
  }
}

# S3 Lifecycle Rule to auto-delete raw input images after 1 day
resource "aws_s3_bucket_lifecycle_configuration" "input_cleanup" {
  bucket = aws_s3_bucket.input.id

  rule {
    id     = "auto-delete-raw-images"
    status = "Enabled"

    expiration {
      days = 1
    }
  }
}

# Create the Secret
resource "aws_secretsmanager_secret" "gemini_key" {
  name                    = "auto-meme/gemini-key-${random_id.suffix.hex}"
  description             = "API Key for Gemini 2.5 Flash"
  recovery_window_in_days = 0
}

# Bootstrap with a dummy value (we will set the real one in the console)
resource "aws_secretsmanager_secret_version" "gemini_key_val" {
  secret_id     = aws_secretsmanager_secret.gemini_key.id
  secret_string = "REPLACE_ME_IN_AWS_CONSOLE"

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# ── CORS on input bucket so browsers can PUT via presigned URL ────────────────
resource "aws_s3_bucket_cors_configuration" "input_cors" {
  bucket = aws_s3_bucket.input.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT"]
    allowed_origins = ["https://${aws_cloudfront_distribution.frontend_cf.domain_name}"]
    max_age_seconds = 3000
  }
}

# ── Frontend S3 static website bucket ────────────────────────────────────────
resource "aws_s3_bucket" "frontend" {
  bucket        = "meme-frontend-${random_id.suffix.hex}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "frontend_block" {
  bucket                  = aws_s3_bucket.frontend.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "frontend_public" {
  depends_on = [aws_s3_bucket_public_access_block.frontend_block]
  bucket     = aws_s3_bucket.frontend.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowCloudFrontServicePrincipalReadOnly"
      Effect    = "Allow"
      Principal = {
        Service = "cloudfront.amazonaws.com"
      }
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.frontend.arn}/*"
      Condition = {
        StringEquals = {
          "AWS:SourceArn" = aws_cloudfront_distribution.frontend_cf.arn
        }
      }
    }]
  })
}