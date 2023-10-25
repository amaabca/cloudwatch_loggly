# frozen_string_literal: true

require 'zlib'
require 'base64'
require 'stringio'
require 'json'
require 'uri'
require 'net/http'
require 'aws-sdk-lambda'

require_relative 'loggly/exceptions/base'
require_relative 'loggly/exceptions/client_error'
require_relative 'loggly/exceptions/server_error'
require_relative 'loggly/exceptions/timeout'
require_relative 'loggly/client'
require_relative 'cloudwatch/event'

module Push
  class << self
    def handle(event:, context:)
      Cloudwatch::Event.new(raw: event).to_loggly!
    end
  end
end
