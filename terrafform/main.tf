# Configure the AWS provider
provider "aws" {
  region = "us-east-1"  # Change to your desired region
}

# Create a DynamoDB table named Nebula with primary key 'email'
resource "aws_dynamodb_table" "nebula" {
  name         = "Nebula"
  billing_mode = "PAY_PER_REQUEST"

  hash_key = "email"

  attribute {
    name = "email"
    type = "S"
  }
}

# IAM Role for Lambda functions
resource "aws_iam_role" "lambda_role" {
  name = "lambda_role"

  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role_policy.json
}

data "aws_iam_policy_document" "lambda_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# IAM Policy for Lambda to access DynamoDB
resource "aws_iam_policy" "lambda_policy" {
  name        = "lambda_policy"
  description = "Policy for Lambda functions to access DynamoDB table"

  policy = data.aws_iam_policy_document.lambda_policy_document.json
}

data "aws_iam_policy_document" "lambda_policy_document" {
  statement {
    actions = [
      "dynamodb:PutItem",
      "dynamodb:GetItem",
      "dynamodb:Scan",
      "dynamodb:Query",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem"
    ]

    resources = [
      aws_dynamodb_table.nebula.arn,
      "${aws_dynamodb_table.nebula.arn}/index/*"
    ]
  }
}

# Attach policies to the Lambda role
resource "aws_iam_role_policy_attachment" "lambda_role_policy_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

resource "aws_iam_role_policy_attachment" "lambda_logging" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Package and create Lambda functions
# PostUser Lambda Function
resource "null_resource" "package_postuser" {
  provisioner "local-exec" {
    command = "cd $Nebula/lambda && zip postuser.zip post.py"
  }
}

resource "aws_lambda_function" "postuser" {
  function_name = "postuser"
  runtime       = "python3.8"
  handler       = "post.lambda_handler"
  role          = aws_iam_role.lambda_role.arn
  filename      = "$Nebula/lambda/postuser.zip"

  depends_on = [null_resource.package_postuser]
}

# GetUser Lambda Function
resource "null_resource" "package_getuser" {
  provisioner "local-exec" {
    command = "cd $Nebula/lambda && zip getuser.zip get.py"
  }
}

resource "aws_lambda_function" "getuser" {
  function_name = "getuser"
  runtime       = "python3.8"
  handler       = "get.lambda_handler"
  role          = aws_iam_role.lambda_role.arn
  filename      = "$Nebula/lambda/getuser.zip"

  depends_on = [null_resource.package_getuser]
}

# RetrieveUserNo Lambda Function
resource "null_resource" "package_retrieveuserno" {
  provisioner "local-exec" {
    command = "cd $Nebula/lambda && zip retrieveuserno.zip retrieveuserno.py"
  }
}

resource "aws_lambda_function" "retrieveuserno" {
  function_name = "retrieveuserno"
  runtime       = "python3.8"
  handler       = "retrieveuserno.lambda_handler"
  role          = aws_iam_role.lambda_role.arn
  filename      = "$Nebula/lambda/retrieveuserno.zip"

  depends_on = [null_resource.package_retrieveuserno]
}

# API Gateway REST API
resource "aws_api_gateway_rest_api" "api" {
  name = "NebulaAPI"
}

# Root resource ("/")
data "aws_api_gateway_resource" "root" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  path        = "/"
}

# POST method at root ("/")
resource "aws_api_gateway_method" "post_method" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = data.aws_api_gateway_resource.root.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "post_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = data.aws_api_gateway_resource.root.id
  http_method             = aws_api_gateway_method.post_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.postuser.invoke_arn
}

# GET method at root ("/")
resource "aws_api_gateway_method" "get_method" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = data.aws_api_gateway_resource.root.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "get_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = data.aws_api_gateway_resource.root.id
  http_method             = aws_api_gateway_method.get_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.getuser.invoke_arn
}

# Resource for "/retrieveuserno"
resource "aws_api_gateway_resource" "retrieveuserno_resource" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = data.aws_api_gateway_resource.root.id
  path_part   = "retrieveuserno"
}

# GET method at "/retrieveuserno"
resource "aws_api_gateway_method" "retrieveuserno_get_method" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.retrieveuserno_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "retrieveuserno_get_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.retrieveuserno_resource.id
  http_method             = aws_api_gateway_method.retrieveuserno_get_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.retrieveuserno.invoke_arn
}

# Lambda Permissions for API Gateway to invoke
resource "aws_lambda_permission" "apigw_post" {
  statement_id  = "AllowAPIGatewayInvokePost"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.postuser.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "apigw_get" {
  statement_id  = "AllowAPIGatewayInvokeGet"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.getuser.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "apigw_retrieveuserno" {
  statement_id  = "AllowAPIGatewayInvokeRetrieveUserNo"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.retrieveuserno.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

# Enable CORS - OPTIONS method at root
resource "aws_api_gateway_method" "options_root" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = data.aws_api_gateway_resource.root.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "options_root_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = data.aws_api_gateway_resource.root.id
  http_method             = aws_api_gateway_method.options_root.http_method
  type                    = "MOCK"
  passthrough_behavior    = "WHEN_NO_MATCH"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }

  integration_response {
    status_code = "200"

    response_parameters = {
      "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
      "method.response.header.Access-Control-Allow-Methods" = "'GET,POST,OPTIONS'"
      "method.response.header.Access-Control-Allow-Origin"  = "'*'"
    }

    response_templates = {
      "application/json" = ""
    }
  }
}

resource "aws_api_gateway_method_response" "options_root_response" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = data.aws_api_gateway_resource.root.id
  http_method = aws_api_gateway_method.options_root.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

# Enable CORS - OPTIONS method at "/retrieveuserno"
resource "aws_api_gateway_method" "options_retrieveuserno" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.retrieveuserno_resource.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "options_retrieveuserno_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.retrieveuserno_resource.id
  http_method             = aws_api_gateway_method.options_retrieveuserno.http_method
  type                    = "MOCK"
  passthrough_behavior    = "WHEN_NO_MATCH"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }

  integration_response {
    status_code = "200"

    response_parameters = {
      "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
      "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS'"
      "method.response.header.Access-Control-Allow-Origin"  = "'*'"
    }

    response_templates = {
      "application/json" = ""
    }
  }
}

resource "aws_api_gateway_method_response" "options_retrieveuserno_response" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.retrieveuserno_resource.id
  http_method = aws_api_gateway_method.options_retrieveuserno.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

# Deploy the API
resource "aws_api_gateway_deployment" "deployment" {
  depends_on = [
    aws_api_gateway_integration.post_integration,
    aws_api_gateway_integration.get_integration,
    aws_api_gateway_integration.retrieveuserno_get_integration,
    aws_api_gateway_integration.options_root_integration,
    aws_api_gateway_integration.options_retrieveuserno_integration
  ]

  rest_api_id = aws_api_gateway_rest_api.api.id
  stage_name  = "prod"
}
