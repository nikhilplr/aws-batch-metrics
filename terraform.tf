terraform {
  required_version = ">= 1.7.0, < 2.0.0"
}

data "aws_caller_identity" "current" {} 
 

locals {
  aws_account_id = data.aws_caller_identity.current.account_id 
  aws_region     = var.region
  archive_name   = var.lambda_archive
  archive_folder = dirname(local.archive_name)
  tags = merge(
    var.tags,
    { "lambda:createdBy" = "Terraform" }
  )
}

 

data "aws_iam_policy_document" "lambda_assume_policy" {
  statement {
    actions = [
      "sts:AssumeRole"
    ]
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# IAM Role for Lambda function
resource "aws_iam_role" "lambda_execution_role" {
  name = "lambda_execution_role"

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

# Attach a policy to allow Lambda to write to CloudWatch and interact with SNS
resource "aws_iam_role_policy" "lambda_policy" {
  role = aws_iam_role.lambda_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "*"
      } ,{
        Effect = "Allow",
        Action = [
          "cloudwatch:PutMetricData"
        ],
        Resource = "*"
      }
      
    ]
  })
}
 
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.service_name}"
  retention_in_days = var.lambda_log_retention_in_days 
  tags = local.tags
}

resource "null_resource" "build_lambda" {
  count = var.build_lambda ? 1 : 0
  // Depends on log group, just in case this is created in a brand new AWS Subaccount, and it doesn't have subscriptions yet.
  depends_on = [aws_cloudwatch_log_group.lambda_logs]

  provisioner "local-exec" {
    // OS Agnostic folder creation.
    command = (local.archive_folder != "."
      ? "mkdir ${local.archive_folder} || mkdir -p ${local.archive_folder}"
      : "echo Folder Exists"
    )
    on_failure = continue
  }

  provisioner "local-exec" {
    command     = "docker build -t ${var.lambda_image_name} --network host ."
    working_dir = path.module
  }

  provisioner "local-exec" {
    command     = "docker run --rm --entrypoint cat ${var.lambda_image_name} /lambda_function.zip > ${abspath(local.archive_name)}"
    working_dir = path.module
  }

  provisioner "local-exec" {
    command    = "docker image rm ${var.lambda_image_name}"
    on_failure = continue
  }
}

resource "aws_lambda_function" "batch_emr_metric_function" {
  depends_on = [
    aws_iam_role.lambda_execution_role,
    aws_cloudwatch_log_group.lambda_logs,
    null_resource.build_lambda,
  ]

  function_name = var.service_name
  description   = "Sends Events coming to the SNS topic to NewRelic"
  role          = aws_iam_role.lambda_execution_role.arn
  runtime       = var.runtime
  filename      = local.archive_name
  handler       = "lambda_function.lambda_handler"
  memory_size   = var.memory_size
  timeout       = var.timeout  
  tags = local.tags
}
 

 

# EventBridge Rule for AWS Batch metrics
resource "aws_cloudwatch_event_rule" "batch_metrics_rule" {
  count       = var.batch_enabled
  name        = "aws_batch_metric_rule"
  description = "Triggers Lambda for AWS Batch metric events"
  event_pattern = jsonencode({
    "source": ["aws.batch"],
    "detail-type": ["Batch Job State Change"],
    "detail": {
      "status": ["SUCCEEDED", "FAILED", "RUNNING", "STARTING"]
    }
  })
}

# EventBridge Rule for AWS EMR metrics
resource "aws_cloudwatch_event_rule" "emr_metrics_rule" {
  count       = var.emr_enabled
  name        = "aws_emr_metric_rule"
  description = "Triggers Lambda for AWS EMR metric events"
  event_pattern = jsonencode({
    "source": ["aws.emr"],
    "detail-type": ["EMR Job State Change"],
    "detail": {
      "state": ["STARTING", "RUNNING", "FAILED", "COMPLETED"]
    }
  })
}

# EventBridge Target for Batch metrics rule
resource "aws_cloudwatch_event_target" "batch_metrics_target" {
  count     = var.batch_enabled
  rule      = aws_cloudwatch_event_rule.batch_metrics_rule[0].name
  arn       = aws_lambda_function.batch_emr_metric_function.arn
}

# EventBridge Target for EMR metrics rule
resource "aws_cloudwatch_event_target" "emr_metrics_target" {
  count     = var.emr_enabled
  rule      = aws_cloudwatch_event_rule.emr_metrics_rule[0].name
  arn       = aws_lambda_function.batch_emr_metric_function.arn
}

# Grant Lambda permission to be invoked by EventBridge rules
resource "aws_lambda_permission" "batch_metrics_permission" {
  count        = var.batch_enabled
  statement_id  = "AllowExecutionFromBatchEvents"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.batch_emr_metric_function.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.batch_metrics_rule[0].arn
}

resource "aws_lambda_permission" "emr_metrics_permission" {
  count         = var.emr_enabled
  statement_id  = "AllowExecutionFromEMREvents"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.batch_emr_metric_function.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.emr_metrics_rule[0].arn
}
 

output "function_arn" {
  value       = aws_lambda_function.batch_emr_metric_function.arn
  description = "Batch EMR metric lambda function ARN"
}

output "lambda_archive" {
  depends_on = [null_resource.build_lambda]
  value      = local.archive_name
}