resource "aws_apigatewayv2_api" "http_api" {
  name          = "wsem-http-api-${var.environment}"
  protocol_type = "HTTP"
  description   = "HTTP API for WSEM backend services"
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  for_each = var.lambdas

  api_id                 = aws_apigatewayv2_api.http_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.this[each.key].invoke_arn
  integration_method     = each.value.integration_method
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "lambda_route" {
  for_each = var.lambdas

  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = each.value.route_key # This replaces OpenAPI and scales per Lambda.
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration[each.key].id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "apigw" {
  for_each = var.lambdas

  statement_id  = "AllowExecutionFromAPIGateway-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this[each.key].function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.http_api.execution_arn}/*"
}
