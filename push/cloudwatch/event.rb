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
        logger.push!(messages)
      end

      private

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
          supplied_tags
        ]
          .join(',')
          .squeeze(',')
      end

      def implied_tags
        "#{owner},#{log_group}"
      end

      def owner
        data.fetch('owner')
      end

      def log_group
        # coerce to loggly tag restrictions. alphanumeric, max 64 characters
        data.fetch('logGroup').split('/').last.gsub(/\W/, '')[0..64]
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
