require 'json'
require 'time'
require 'aws-sdk-lambda'
require 'aws-sdk-cloudwatchlogs'

require_relative 'lambda/function'

module Subscribe
  class << self
    def handle(event:, context:)
      Lambda::Function.subscribe_all!.tap do |data|
        puts data.to_json if ENV.fetch('LOG_OUTPUT', 'true').casecmp('true').zero?
      end
    end
  end
end
