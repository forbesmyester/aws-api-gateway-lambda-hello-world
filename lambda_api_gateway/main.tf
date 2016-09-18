variable "aws_lambda_function" {}
variable "region" {}

variable "aws_api_gateway_rest_api" {}
variable "aws_api_gateway_resource" {}
variable "aws_api_gateway_method" {}


resource "aws_api_gateway_integration" "role_put" { # TODO: Module
    rest_api_id = "${var.aws_api_gateway_rest_api.id}"
    resource_id = "${var.aws_api_gateway_resource.id}"
    http_method = "${var.aws_api_gateway_method.http_method}"
    type = "AWS"
    uri = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${var.aws_lambda_function.arn}/invocations"
    integration_http_method = "POST"
    request_templates = {
        "application/json" = "${file("./body_mapping_template/method_request_passthrough")}"
    }
}

