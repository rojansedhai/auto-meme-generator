resource "aws_iam_role" "sfn_role" {
  name = "meme_sfn_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "states.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "sfn_policy" {
  role = aws_iam_role.sfn_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action   = "lambda:InvokeFunction"
      Effect   = "Allow"
      Resource = "*"
    }]
  })
}

resource "aws_sfn_state_machine" "sfn" {
  name     = "MemeWorkflow"
  role_arn = aws_iam_role.sfn_role.arn

  definition = jsonencode({
    StartAt = "Analyze"
    States = {
      Analyze = {
        Type     = "Task"
        Resource = aws_lambda_function.analyze.arn
        Next     = "Caption"
        # Resilience: Retry on transient errors
        Retry = [{
          ErrorEquals = ["States.TaskFailed"]
          IntervalSeconds = 2
          MaxAttempts = 2
          BackoffRate = 2.0
        }]
        # Resilience: Catch all other errors and exit gracefully
        Catch = [{
          ErrorEquals = ["States.ALL"]
          Next = "ProcessingFailed"
        }]
      }
      Caption = {
        Type     = "Task"
        Resource = aws_lambda_function.caption.arn
        Next     = "Compose"
        Catch = [{ ErrorEquals = ["States.ALL"], Next = "ProcessingFailed" }]
      }
      Compose = {
        Type     = "Task"
        Resource = aws_lambda_function.compose.arn
        End      = true
        Catch = [{ ErrorEquals = ["States.ALL"], Next = "ProcessingFailed" }]
      }
      # The Graceful Failure State
      ProcessingFailed = {
        Type  = "Fail"
        Cause = "An error occurred during meme generation."
        Error = "WorkflowError"
      }
    }
  })
}