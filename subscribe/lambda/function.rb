# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength

module Subscribe
  module Lambda
    class Function
      FILTER_NAME = 'ShipToLoggly'

      attr_accessor :name, :arn, :tags, :lambda, :cloudwatch

      class << self
        def all(lambda = build_lambda_client, cloudwatch = build_cloudwatchlogs_client)
          all_functions(lambda).map do |function|
            new(
              name: function.function_name,
              arn: function.function_arn,
              lambda: lambda,
              cloudwatch: cloudwatch
            )
          end
        end

        def subscribe_all!(lambda = build_lambda_client, cloudwatch = build_cloudwatchlogs_client)
          data = {
            timestamp: Time.now.iso8601,
            event: 'log.info',
            skipped: [],
            changed: []
          }
          all(lambda, cloudwatch).each_with_object(data) do |function, hash|
            if function.skip?
              hash[:skipped] << function.name
            else
              function.subscribe!
              hash[:changed] << function.name
            end
          end
        end

        def retry_opts
          { max_attempts: 4, retry_mode: 'standard' }
        end

        def build_lambda_client(opts = {})
          Aws::Lambda::Client.new(retry_opts.merge(opts))
        end

        def build_cloudwatchlogs_client(opts = {})
          Aws::CloudWatchLogs::Client.new(retry_opts.merge(opts))
        end

        private

        def all_functions(lambda)
          lambda.list_functions.flat_map(&:functions)
        end
      end

      def initialize(opts = {})
        self.name = opts.fetch(:name)
        self.arn = opts.fetch(:arn)
        self.lambda = opts.fetch(:lambda) { Aws::Lambda::Client.new }
        self.cloudwatch = opts.fetch(:cloudwatch) { Aws::CloudWatchLogs::Client.new }
        self.tags = fetch_tags!
      end

      def skip?
        suppress? || up_to_date?
      end

      def subscribe!
        !!cloudwatch.put_subscription_filter(
          log_group_name: cloudwatch_log_group_name,
          filter_name: FILTER_NAME,
          filter_pattern: filter_pattern,
          destination_arn: destination_arn
        )
      end

      private

      def up_to_date?
        (filter_pattern == remote_filter_pattern) &&
          (destination_arn == remote_destination_arn)
      rescue Aws::CloudWatchLogs::Errors::ResourceNotFoundException
        true
      end

      def suppress?
        !!tags['cloudwatch_loggly_suppress_subscribe']
      end

      def destination_arn
        ENV.fetch('DESTINATION_ARN')
      end

      def filter_pattern
        tags['cloudwatch_loggly_filter_pattern'] || ENV.fetch('FILTER_PATTERN')
      end

      def fetch_tags!
        retries ||= 0
        lambda.list_tags(resource: arn).tags
      rescue Aws::Lambda::Errors::ThrottlingException => e
        puts "ThrottlingExceptionFetchTags (retry attempt: #{retries}): #{e.inspect}"
        retry if (retries += 1) < 3

        puts 'ThrottlingExceptionFetchTagsRetryLimitExceeded'

        []
      end

      def cloudwatch_log_group_name
        "/aws/lambda/#{name}"
      end

      def subscriptions
        @subscriptions ||= begin
          retries ||= 0

          cloudwatch.describe_subscription_filters(
            log_group_name: cloudwatch_log_group_name,
            filter_name_prefix: FILTER_NAME,
            limit: 1
          ).subscription_filters
        end
      rescue Aws::CloudWatchLogs::Errors::ThrottlingException => e
        puts "ThrottlingExceptionSubscriptions (retry attempt: #{retries}): #{e.inspect}"
        retry if (retries += 1) < 3

        puts 'ThrottlingExceptionSubscriptionsRetryLimitExceeded'
        []
      end

      def remote_filter_pattern
        subscriptions.first&.filter_pattern
      end

      def remote_destination_arn
        subscriptions.first&.destination_arn
      end
    end
  end
end
# rubocop:enable Metrics/ClassLength
