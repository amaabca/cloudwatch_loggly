require 'json'
require 'aws-sdk-lambda'
require 'aws-sdk-cloudwatchlogs'

require_relative 'lambda/function'

def handle(event:, context:)
  puts Lambda::Function.subscribe_all!.to_json
end
