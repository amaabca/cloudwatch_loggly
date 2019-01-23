# frozen_string_literal: true

require 'simplecov'
require 'rspec'
require 'webmock/rspec'
require 'pry'
require 'ostruct'
require_relative '../push/handler'
require_relative '../subscribe/handler'

Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }

WebMock.disable_net_connect!

RSpec.configure do |config|
  config.include Helpers::Fixtures
  config.include Helpers::Requests
  config.include Helpers::Environment

  config.example_status_persistence_file_path = '.rspec_status'

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
