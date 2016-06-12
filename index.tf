# == Variables
variable "aws_profile" {}
variable region {
    type = "string"
    default = "us-east-1" # aws_api_gateway_integration needs the region, so cannot be hardcoded
}

# == Account Confuration
provider "aws" {
    profile = "${var.aws_profile}"
    region = "${var.region}"
}

# == Roles/Permissions for Lambda function
# The role is attached to the Lambda function and governs what it can
# do.
resource "aws_iam_role" "plus" {
    name = "api_gateway_lambda"
    assume_role_policy = "${file("./iam_for_lambda.json")}"
}
resource "aws_iam_role_policy" "plus" {
    name = "policy_plus"
    role = "${aws_iam_role.plus.id}"
    policy = "${file("./iam_for_lambda_policy.json")}"
}

# == Lambda function creation
# I was hoping that using a bucket / object method instead of
# aws_lambda_function.filename might make Terraform pick up changes in code
# better but it seems I still need to taint them before running.
resource "aws_lambda_function" "plus" {
    filename = "code.zip"
    function_name = "plus"
    handler = "index.handler"
    runtime = "nodejs4.3"
    role = "${aws_iam_role.plus.arn}"
}

# == Lambda Permission to be exected from API Gateway
# The Lambda function is executed by AWS API Gateway and as such it needs
# permission for it to be executed. Wierdness is that API gateway seems to
# not have an ARN so we cannot specify source_arn here, IE it's seems to be
# available to the whole of API gateway now.
resource "aws_lambda_permission" "plus" {
    statement_id = "plusperm"
    action = "lambda:InvokeFunction"
    function_name = "${aws_lambda_function.plus.arn}"
    principal = "apigateway.amazonaws.com"
}

# == API Gateway: New API
resource "aws_api_gateway_rest_api" "plus" {
    name = "plus"
}

# == API Gateway: Path
# Specify the resource location and tell it that it is to call the Lambda
resource "aws_api_gateway_resource" "plus1" {
    rest_api_id = "${aws_api_gateway_rest_api.plus.id}"
    parent_id = "${aws_api_gateway_rest_api.plus.root_resource_id}"
    path_part = "my"
}
resource "aws_api_gateway_resource" "plus2" {
    rest_api_id = "${aws_api_gateway_rest_api.plus.id}"
    parent_id = "${aws_api_gateway_resource.plus1.id}"
    path_part = "path"
}
resource "aws_api_gateway_method" "plus" {
    rest_api_id = "${aws_api_gateway_rest_api.plus.id}"
    resource_id = "${aws_api_gateway_resource.plus2.id}"
    http_method = "GET"
    authorization = "NONE"
}
resource "aws_api_gateway_integration" "plus" {
    rest_api_id = "${aws_api_gateway_rest_api.plus.id}"
    resource_id = "${aws_api_gateway_resource.plus2.id}"
    http_method = "${aws_api_gateway_method.plus.http_method}"
    type = "AWS"
    uri = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${aws_lambda_function.plus.arn}/invocations"
    integration_http_method = "POST"
}

# == API Gateway: Response
# Map back the Lambda function result into HTTP
resource "aws_api_gateway_method_response" "200" {
    rest_api_id = "${aws_api_gateway_rest_api.plus.id}"
    resource_id = "${aws_api_gateway_resource.plus2.id}"
    http_method = "${aws_api_gateway_method.plus.http_method}"
    status_code = "200"
}
resource "aws_api_gateway_integration_response" "plus" {
    rest_api_id = "${aws_api_gateway_rest_api.plus.id}"
    resource_id = "${aws_api_gateway_resource.plus2.id}"
    http_method = "${aws_api_gateway_method.plus.http_method}"
    status_code = "${aws_api_gateway_method_response.200.status_code}"
    depends_on = ["aws_api_gateway_integration.plus"]
}

# == API Gateway: Deployment
# This add a stage in the UI, which actually adds the public methods. Note:
# currently I am not sure where this should happen and I've also seen it
# not refreshing properly, might need tainting manually etc.
resource "aws_api_gateway_deployment" "plus" {
    rest_api_id = "${aws_api_gateway_rest_api.plus.id}"
    stage_name = "api"
    depends_on = ["aws_api_gateway_integration.plus"]
}

