# frozen_string_literal: true

module Push
  module Loggly
    class Client
      HOST = 'https://logs-01.loggly.com'

      attr_accessor :token, :host, :bulk, :input_type, :uri, :tags

      def initialize(opts = {})
        self.token = opts.fetch(:token)
        self.host = opts.fetch(:host) { HOST }
        self.bulk = opts.fetch(:bulk) { false }
        self.input_type = bulk ? 'bulk' : 'inputs'
        self.tags = opts.fetch(:tags)
        self.uri = URI("#{host}/#{input_type}/#{token}/")
      end

      def push!(messages)
        if bulk
          push_bulk!(messages)
        else
          push_single!(messages)
        end
      end

      private

      def push_single!(messages)
        messages.map do |message|
          body = message.delete("\n")
          request!(body)
        end
      end

      def push_bulk!(messages)
        body = messages.map { |message| message.delete("\n") }.join("\n")
        request!(body)
      end

      def request!(data)
        Net::HTTP.start(
          uri.host,
          uri.port,
          open_timeout: 2,
          read_timeout: 5,
          use_ssl: true
        ) do |https|
          request = Net::HTTP::Post.new(uri.request_uri)
          request.body = data
          request['CONTENT-TYPE'] = 'text/plain'
          request['X-LOGGLY-TAG'] = tags
          response = https.request(request)
          Exceptions::Base.from_http(response)
        end
      rescue Net::OpenTimeout, Net::ReadTimeout
        raise Exceptions::Timeout, 'server timeout'
      end
    end
  end
end
