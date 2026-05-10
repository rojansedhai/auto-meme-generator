resource "aws_s3_bucket_notification" "s3_eventbridge" {
  bucket      = aws_s3_bucket.input.id
  eventbridge = true
}

resource "aws_cloudwatch_event_rule" "rule" {
  name = "meme-trigger"

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["Object Created"]
    detail = {
      bucket = {
        name = [aws_s3_bucket.input.id]
      }
    }
  })
}

resource "aws_iam_role" "eb_role" {
  name = "meme_eb_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "events.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "eb_policy" {
  role = aws_iam_role.eb_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action   = "states:StartExecution"
      Effect   = "Allow"
      Resource = aws_sfn_state_machine.sfn.arn
    }]
  })
}

resource "aws_cloudwatch_event_target" "target" {
  rule     = aws_cloudwatch_event_rule.rule.name
  arn      = aws_sfn_state_machine.sfn.arn
  role_arn = aws_iam_role.eb_role.arn
}