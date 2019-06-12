# frozen_string_literal: true

module Helpers
  module Environment
    def prepare_environment!(opts = {})
      ENV['LOGGLY_TOKEN'] = opts.fetch(:loggly_token) { '1234' }
      ENV['LOG_TAGS'] = opts.fetch(:log_tags) { 'test,spec' }
      ENV['BULK_TRANSMISSION'] = opts.fetch(:bulk) { 'true' }
      ENV['FILTER_PATTERN'] = opts.fetch(:filter_pattern) { '' }
      ENV['DESTINATION_ARN'] = opts.fetch(:destination_arn) do
        'arn:aws:lambda:us-west-2:123456789012:function:func'
      end
      ENV['LOG_OUTPUT'] = opts.fetch(:log_output) { 'false' }
    end
  end
end
