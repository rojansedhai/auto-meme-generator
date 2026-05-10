data "archive_file" "analyze" {
  type        = "zip"
  source_dir  = "../src/analyze"
  output_path = "analyze.zip"
}

data "archive_file" "caption" {
  type        = "zip"
  source_dir  = "../src/caption"
  output_path = "caption.zip"
}

data "archive_file" "compose" {
  type        = "zip"
  source_dir  = "../src/compose"
  output_path = "compose.zip"
}

data "archive_file" "upload" {
  type        = "zip"
  source_dir  = "../src/upload"
  output_path = "upload.zip"
}

data "archive_file" "status" {
  type        = "zip"
  source_dir  = "../src/status"
  output_path = "status.zip"
}

# ── Sharp Lambda Layer ─────────────────────────────────────────────────────────
resource "aws_lambda_layer_version" "sharp" {
  filename            = "sharp_layer.zip"
  layer_name          = "sharp_layer"
  compatible_runtimes = ["nodejs20.x"]
}

# ── Pipeline Lambdas ───────────────────────────────────────────────────────────
resource "aws_lambda_function" "analyze" {
  filename         = "analyze.zip"
  function_name    = "Meme_1_Analyze"
  role             = aws_iam_role.analyze_role.arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  source_code_hash = data.archive_file.analyze.output_base64sha256
}

resource "aws_lambda_function" "caption" {
  filename         = "caption.zip"
  function_name    = "Meme_2_Caption"
  role             = aws_iam_role.caption_role.arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  timeout          = 15
  source_code_hash = data.archive_file.caption.output_base64sha256

  environment {
    variables = {
      SECRET_ID = aws_secretsmanager_secret.gemini_key.name
    }
  }
}

resource "aws_lambda_function" "compose" {
  filename         = "compose.zip"
  function_name    = "Meme_3_Compose"
  role             = aws_iam_role.compose_role.arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  timeout          = 30
  layers           = [aws_lambda_layer_version.sharp.arn]
  source_code_hash = data.archive_file.compose.output_base64sha256

  environment {
    variables = {
      OUTPUT_BUCKET   = aws_s3_bucket.output.id
      TABLE_NAME      = aws_dynamodb_table.registry.name
      FONTCONFIG_PATH = "/var/task/fonts"
    }
  }
}

# ── API Lambdas ────────────────────────────────────────────────────────────────
resource "aws_lambda_function" "upload" {
  filename         = "upload.zip"
  function_name    = "Meme_0_Upload"
  role             = aws_iam_role.upload_role.arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  timeout          = 10
  source_code_hash = data.archive_file.upload.output_base64sha256

  environment {
    variables = {
      INPUT_BUCKET = aws_s3_bucket.input.id
      TABLE_NAME   = aws_dynamodb_table.registry.name
    }
  }
}

resource "aws_lambda_function" "status" {
  filename         = "status.zip"
  function_name    = "Meme_Status"
  role             = aws_iam_role.status_role.arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  timeout          = 10
  source_code_hash = data.archive_file.status.output_base64sha256

  environment {
    variables = {
      OUTPUT_BUCKET = aws_s3_bucket.output.id
      TABLE_NAME    = aws_dynamodb_table.registry.name
    }
  }
}