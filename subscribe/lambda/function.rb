module Lambda
  class Function
    attr_accessor :name, :arn, :tags

    class << self
      def all
        client = Aws::Lambda::Client.new
        client.list_functions.functions.map do |function|
          new(name: function.function_name, arn: function.function_arn)
        end
      end

      def subscribe_all!
        data = { event: 'log.info', skipped: [], changed: [] }
        all.each_with_object(data) do |function, hash|
          if function.skip?
            hash[:skipped] << function.name
          else
            function.subscribe!
            hash[:changed] << function.name
          end
        end
      end
    end

    def initialize(opts = {})
      self.name = opts.fetch(:name)
      self.arn = opts.fetch(:arn)
      self.tags = fetch_tags!
    end

    def skip?
      suppress? || up_to_date?
    end

    def subscribe!
      cloudwatch.put_subscription_filter(
        log_group_name: cloudwatch_log_group_name,
        filter_name: 'ShipToLoggly',
        filter_pattern: filter_pattern,
        destination_arn: destination_arn
      )
    end

    private

    def up_to_date?
      !stale?
    end

    def suppress?
      !!tags['suppress_log_subscribe']
    end

    def stale?
      filter_pattern != remote_filter_pattern
    rescue Aws::CloudWatchLogs::Errors::ResourceNotFoundException
      false
    end

    def cloudwatch
      @cloudwatch ||= Aws::CloudWatchLogs::Client.new
    end

    def lambda
      @lambda ||= Aws::Lambda::Client.new
    end

    def destination_arn
      ENV.fetch('DESTINATION_ARN')
    end

    def filter_pattern
      ENV.fetch('FILTER_PATTERN')
    end

    def fetch_tags!
      client = Aws::Lambda::Client.new
      client.list_tags(resource: arn).tags
    end

    def cloudwatch_log_group_name
      "/aws/lambda/#{name}"
    end

    def remote_filter_pattern
      cloudwatch.describe_subscription_filters(
        log_group_name: cloudwatch_log_group_name,
        filter_name_prefix: 'ShipToLoggly',
        limit: 1
      )
        .subscription_filters
        .first
        &.filter_pattern
    end
  end
end
