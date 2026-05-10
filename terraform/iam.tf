# Base Assume Role Policy for Lambda
data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# --- 1. Analyze Role ---
resource "aws_iam_role" "analyze_role" {
  name               = "meme_analyze_role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}
resource "aws_iam_role_policy" "analyze_policy" {
  name   = "meme_analyze_policy"
  role   = aws_iam_role.analyze_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Action = ["logs:*"],                   Effect = "Allow", Resource = "arn:aws:logs:*:*:*" },
      { Action = ["s3:GetObject"],             Effect = "Allow", Resource = "${aws_s3_bucket.input.arn}/*" },
      { Action = ["rekognition:DetectLabels"], Effect = "Allow", Resource = "*" }
    ]
  })
}

# --- 2. Caption Role ---
resource "aws_iam_role" "caption_role" {
  name               = "meme_caption_role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}
resource "aws_iam_role_policy" "caption_policy" {
  name   = "meme_caption_policy"
  role   = aws_iam_role.caption_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Action = ["logs:*"],                          Effect = "Allow", Resource = "arn:aws:logs:*:*:*" },
      { Action = ["secretsmanager:GetSecretValue"],   Effect = "Allow", Resource = aws_secretsmanager_secret.gemini_key.arn }
    ]
  })
}

# --- 3. Compose Role ---
resource "aws_iam_role" "compose_role" {
  name               = "meme_compose_role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}
resource "aws_iam_role_policy" "compose_policy" {
  name   = "meme_compose_policy"
  role   = aws_iam_role.compose_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Action = ["logs:*"],                              Effect = "Allow", Resource = "arn:aws:logs:*:*:*" },
      { Action = ["s3:GetObject"],                        Effect = "Allow", Resource = "${aws_s3_bucket.input.arn}/*" },
      { Action = ["s3:PutObject"],                        Effect = "Allow", Resource = "${aws_s3_bucket.output.arn}/*" },
      # PutItem for backward-compat; UpdateItem needed to flip PENDING → COMPLETED
      { Action = ["dynamodb:PutItem", "dynamodb:UpdateItem"], Effect = "Allow", Resource = aws_dynamodb_table.registry.arn }
    ]
  })
}

# --- 4. Upload Role ---
resource "aws_iam_role" "upload_role" {
  name               = "meme_upload_role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}
resource "aws_iam_role_policy" "upload_policy" {
  name   = "meme_upload_policy"
  role   = aws_iam_role.upload_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Action = ["logs:*"],           Effect = "Allow", Resource = "arn:aws:logs:*:*:*" },
      { Action = ["s3:PutObject"],     Effect = "Allow", Resource = "${aws_s3_bucket.input.arn}/*" },
      { Action = ["dynamodb:PutItem"], Effect = "Allow", Resource = aws_dynamodb_table.registry.arn }
    ]
  })
}

# --- 5. Status Role ---
resource "aws_iam_role" "status_role" {
  name               = "meme_status_role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}
resource "aws_iam_role_policy" "status_policy" {
  name   = "meme_status_policy"
  role   = aws_iam_role.status_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Action = ["logs:*"],          Effect = "Allow", Resource = "arn:aws:logs:*:*:*" },
      { Action = ["s3:GetObject"],    Effect = "Allow", Resource = "${aws_s3_bucket.output.arn}/*" },
      { Action = ["dynamodb:GetItem"], Effect = "Allow", Resource = aws_dynamodb_table.registry.arn }
    ]
  })
}