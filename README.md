## CloudWatch to Loggly Forwarder

[![Version](https://img.shields.io/github/tag/amaabca/cloudwatch_loggly.svg)](https://img.shields.io/github/tag/amaabca/cloudwatch_loggly.svg)
[![Build Status](https://travis-ci.com/amaabca/cloudwatch_loggly.svg?branch=master)](https://travis-ci.com/amaabca/cloudwatch_loggly.svg?branch=master)

Cloudwatch::Loggly is an AWS [SAM](https://github.com/awslabs/serverless-application-model) application that automatically ships the logs from Lambda functions to [Loggly](https://www.loggly.com).

### Overview

The SAM template contains two key Lambda functions:

#### Push Function

This function is responsible for sending events to Loggly.

This function is designed to be triggered by Cloudwatch Log [events](https://docs.aws.amazon.com/lambda/latest/dg/invoking-lambda-function.html#supported-event-source-cloudwatch-logs).

The Push function reads Cloudwatch Log data via the incoming event, decompresses it and sends the data via Loggly's [HTTP API](https://www.loggly.com/docs/api-sending-data/).

#### Subscribe Function

This function periodically wakes up and lists all Lambda functions in its current region.

For each function in the region, a [subscription filter](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/CreateSubscriptionFilter.html) is created for the corresponding function's log group. This filter triggers the Push function to deliver data to Loggly.

The interval that this function executes is configurable via the `ScheduleExpressionParameter` template parameter. Please see the AWS [schedule expression documentation](https://docs.aws.amazon.com/lambda/latest/dg/tutorial-scheduled-events-schedule-expressions.html) for allowed values.

### Configuration

The SAM template accepts the following parameters:

- **LogglyTokenParameter** [required]: The Loggly customer token to send data via the API.
- **LogTagsParameter** [optional]: A comma separated list of strings that will be sent as tags to Loggly when events are ingested.
- **FilterPatternParameter** [optional]: The AWS [filter expression](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/FilterAndPatternSyntax.html) that is used when subscribing to log groups. By default, all log group events are captured.
- **BulkTransmissionParameter** [optional]: Determines if Loggly's bulk transmission endpoint should be used for efficiency. Defaults to 'true'.
- **ScheduleExpressionParameter** [optional]: The AWS schedule expression for the Subscribe function trigger. By default, this executes daily at 16:00 UTC.
- **FunctionTimeoutParameter** [optional]: The Lambda timeout value in seconds for both the Push and Subscribe function. This value defaults to '10'.

### Parameter Overrides

Lambda functions may be tagged with "special" values to override default behaviour.

#### `cloudwatch_loggly_suppress_subscribe`

This application assumes an "opt-out" approach when shipping logs. By default, the log groups for all Lambda functions in a region are subscribed to deliver data to Loggly.

If you wish to opt-out a Lambda function from Loggly delivery, add the `cloudwatch_loggly_suppress_subscribe` tag to the function with any non-blank value.

#### `cloudwatch_loggly_filter_pattern`

By default, the value from the `FilterPatternParameter` is used when subscribing to CloudWatch log events. This value can be overridden on a per-function basis by setting the Lambda function's `cloudwatch_loggly_filter_pattern` tag to the value that you prefer.

### Adding tags to cloudwatch for a lambda

By default, the only tags that will be sent to loggly are the ones specified in `LogTagsParameter`, the owner (account number) and the log group that the logs are from. If you would like to send additional tags then you must add a tag to the lambda that starts with `cloudwatch_loggly_tag`. For example a log group with the tag `cloudwatch_loggly_mfe: omninotes` will have the tag `omninotes` added to the loggly tags.

### Deploying to the AWS Serverless Application Repository

1. Ensure you have the `aws` and `sam` CLI tools installed locally.
2. Ensure Docker is installed (the `--use-container` flag is specified during the build phase).
3. Update the `SemanticVersion` value in `template.yml`.
4. run `AWS_PROFILE=myprofilename make`

**NOTE**: After publishing a new version, it can take AWS a few hours to propagate the changes across regions. You'll likely see the version update on the Serverless Application Repository in `us-east-1` first.

### Licence

Cloudwatch::Loggly is licensed under the MIT License. Please see LICENSE for details.
