resource "aws_lambda_function" "this" {
  for_each = var.lambdas

  function_name = "${each.key}-${var.environment}"
  role          = aws_iam_role.lambda_exec.arn

  handler     = each.value.handler
  runtime     = each.value.runtime
  memory_size = each.value.memory_size
  timeout     = each.value.timeout

  s3_bucket = var.artifacts_bucket_name
  s3_key    = "lambda/${each.key}/${each.value.artifact_key}"

  environment {
    variables = {
      ENV = var.environment
    }
  }
}

/*
Later calling module would be like:
module "backend" {
  source = "../../modules/backend"

  environment           = "dev"
  artifacts_bucket_name = ...
  lambdas = {
    image_processor = {
      handler      = "app.handler.handler"
      runtime      = "python3.10"
      artifact_key = "image-processor.1.0.0.zip"
    }
  }
}

*/
