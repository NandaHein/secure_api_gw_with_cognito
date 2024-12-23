resource "aws_cognito_user_pool" "secure_api_pool" {
  name                     = var.cognito_pool_name
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

}

resource "aws_cognito_user_pool_client" "secure_api_pool_app_client" {
  name                                 = var.cognito_app_client_name
  user_pool_id                         = aws_cognito_user_pool.secure_api_pool.id
  allowed_oauth_flows                  = ["implicit"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes                 = ["openid", "phone", "email", "aws.cognito.signin.user.admin"]
  callback_urls                        = ["https://example.com"]
  supported_identity_providers         = ["COGNITO"]
}

resource "aws_cognito_user_pool_domain" "secure_api_pool_domain" {
  domain = var.cognito_domain_name
  #domain       = "secure-api-pool-domain"
  user_pool_id = aws_cognito_user_pool.secure_api_pool.id
}

######################## lambda function and required permissions #######################
resource "aws_iam_role" "lambda_execution_role" {
  name = "lambda_execution_role"
  #managed_policy_arns = ["arn:aws:iam::aws:policy/AdministratorAccess"]
  assume_role_policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : [
            "sts:AssumeRole"
          ],
          "Principal" : {
            "Service" : [
              "lambda.amazonaws.com"
            ]
          }
        }
      ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_execution_role_policy" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "lambda_function" {
  function_name    = "APIGW_to_Lambda_Backend"
  role             = aws_iam_role.lambda_execution_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.9"
  architectures    = ["x86_64"]
  filename         = "lambda_python.zip"
  source_code_hash = filebase64sha256("lambda_python.zip")
}

######################## API Gateway ###########################
resource "aws_api_gateway_rest_api" "rest_apigw" {
  name = "rest_apigw"
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}


##################API GW Authorizer####################
resource "aws_api_gateway_authorizer" "aws_api_gateway_authorizer_cognito" {
  name          = "my_cognito_authorizer"
  rest_api_id   = aws_api_gateway_rest_api.rest_apigw.id
  type          = "COGNITO_USER_POOLS"
  provider_arns = [aws_cognito_user_pool.secure_api_pool.arn]
}

##################### Lambda API Resource ############################
resource "aws_api_gateway_resource" "lambda_resource" {
  rest_api_id = aws_api_gateway_rest_api.rest_apigw.id
  parent_id   = aws_api_gateway_rest_api.rest_apigw.root_resource_id
  path_part   = "lambda"
}

resource "aws_api_gateway_method" "Lambda_Method" {
  rest_api_id   = aws_api_gateway_rest_api.rest_apigw.id
  resource_id   = aws_api_gateway_resource.lambda_resource.id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.aws_api_gateway_authorizer_cognito.id
}

resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.rest_apigw.id
  resource_id             = aws_api_gateway_resource.lambda_resource.id
  http_method             = aws_api_gateway_method.Lambda_Method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambda_function.invoke_arn
}

resource "aws_api_gateway_method_response" "lambda_response_200" {
  rest_api_id = aws_api_gateway_rest_api.rest_apigw.id
  resource_id = aws_api_gateway_resource.lambda_resource.id
  http_method = aws_api_gateway_method.Lambda_Method.http_method
  status_code = "200"
  response_models = {
    "application/json" = "Empty"
  }
}

#Gives an external source (like an EventBridge Rule, SNS, or S3 or API GW) permission to access the Lambda function.
resource "aws_lambda_permission" "lambda_permission_to_APIGW" {
  statement_id  = "AllowRestAPIInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_function.function_name
  principal     = "apigateway.amazonaws.com"

  # The /* part allows invocation from any stage, method and resource path
  # within API Gateway.
  source_arn = "${aws_api_gateway_rest_api.rest_apigw.execution_arn}/*"
  depends_on = [
    aws_api_gateway_rest_api.rest_apigw
  ]
}

############################ API GW Deployment ###############################
resource "aws_api_gateway_deployment" "api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.rest_apigw.id
  depends_on = [
    aws_api_gateway_integration.lambda_integration
  ]
}

resource "aws_api_gateway_stage" "api_stage_deployment" {
  rest_api_id   = aws_api_gateway_rest_api.rest_apigw.id
  deployment_id = aws_api_gateway_deployment.api_deployment.id
  stage_name    = var.stage_name
}