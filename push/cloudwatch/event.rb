# frozen_string_literal: true

module Push
  module Cloudwatch
    class Event
      attr_accessor :raw

      def initialize(opts = {})
        self.raw = opts.fetch(:raw)
      end

      def to_loggly!
        messages = events.map { |e| e.fetch('message') }
        puts('to_loggly!')
        puts(messages)
        puts(data)
        logger.push!(messages)
      end

      private

      def retry_opts
        { max_attempts: 4, retry_mode: 'standard' }
      end

      # rubocop:disable Metrics/AbcSize
      def get_lambda_tags(opts = {})
        retries ||= 0

        Aws::Lambda::Client.new(retry_opts.merge(opts)).list_tags(
          resource: 'arn:aws:lambda:' + ENV.fetch('REGION') + ':' + owner + ':function:' + log_group
        ).tags
      rescue Aws::Lambda::Errors::ThrottlingException => e
        puts "ThrottlingExceptionGetLambdaTags (retry attempt: #{retries}): #{e.inspect}"
        retry if (retries += 1) < 3

        puts 'ThrottlingExceptionGetLambdaTagsRetryLimitExceeded'

        []
      end
      # rubocop:enable Metrics/AbcSize

      def data
        @data ||= JSON.parse(decompressor.read)
      end

      def events
        data.fetch('logEvents') { [] }
      end

      def logger
        @logger ||= Loggly::Client.new(token: token, tags: tags, bulk: bulk?)
      end

      def bulk?
        ENV.fetch('BULK_TRANSMISSION').casecmp('true').zero?
      end

      def token
        ENV.fetch('LOGGLY_TOKEN')
      end

      def tags
        [
          implied_tags,
          supplied_tags,
          lambda_tags
        ]
          .join(',')
          .squeeze(',')
      end

      def lambda_tags
        tags_to_add = []
        get_lambda_tags.each do |key, value|
          tags_to_add.push(value) if key.include? 'cloudwatch_loggly_tag'
        end

        tags_to_add
      end

      def implied_tags
        "#{owner},#{truncated_log_group}"
      end

      def owner
        data.fetch('owner')
      end

      def truncated_log_group
        # coerce to loggly tag restrictions. alphanumeric, max 64 characters
        log_group.gsub(/\W/, '')[0..64]
      end

      def log_group
        data.fetch('logGroup').split('/').last
      end

      def supplied_tags
        ENV.fetch('LOG_TAGS')
      end

      def decompressor
        Zlib::GzipReader.new(StringIO.new(binary))
      end

      def binary
        Base64.decode64(raw.dig('awslogs', 'data'))
      end
    end
  end
end
