# frozen_string_literal: true

describe Subscribe::Lambda::Function do
  let(:tags) { { 'test' => 'true' } }
  let(:destination_arn) { ENV.fetch('DESTINATION_ARN') }
  let(:lambda) { described_class.build_lambda_client(stub_responses: true) }
  let(:cloudwatch) { described_class.build_cloudwatchlogs_client(stub_responses: true) }
  let(:tags_stub) { lambda.stub_data(:list_tags, tags: tags) }
  let(:function_one_arn) { 'arn:aws:lambda:us-west-2:123456789012:function:One' }
  let(:function_two_arn) { 'arn:aws:lambda:us-west-2:123456789012:function:Two' }
  let(:function_three_arn) { 'arn:aws:lambda:us-west-2:123456789012:function:Three' }
  let(:functions) do
    [
      {
        function_name: 'one',
        function_arn: function_one_arn
      },
      {
        function_name: 'two',
        function_arn: function_two_arn
      }
    ]
  end
  let(:more_functions) do
    [
      {
        function_name: 'three',
        function_arn: function_three_arn
      }
    ]
  end
  let(:functions_stub) { lambda.stub_data(:list_functions, functions: functions) }
  subject do
    described_class.new(
      arn: 'test',
      name: 'test',
      cloudwatch: cloudwatch,
      lambda: lambda
    )
  end

  before(:each) do
    prepare_environment!
  end

  describe '#initialize' do
    context 'when hitting throttling exceptions' do
      before(:each) do
        allow(lambda).to receive(:list_tags).and_raise(
          Aws::Lambda::Errors::ThrottlingException.new('test', 'test')
        )
      end

      it 'retries method 3 times for each function' do
        described_class.new(
          arn: 'test',
          name: 'test',
          cloudwatch: cloudwatch,
          lambda: lambda
        )

        expect(lambda).to have_received(:list_tags).exactly(3).times
      end
    end
  end

  describe '#subscribe!' do
    let(:subscription_filter_stub) { cloudwatch.stub_data(:put_subscription_filter, {}) }

    before(:each) do
      lambda.stub_responses(:list_tags, tags_stub)
      cloudwatch.stub_responses(:put_subscription_filter, subscription_filter_stub)
    end

    it 'returns true' do
      expect(subject.subscribe!).to be true
    end
  end

  describe '#skip?' do
    before(:each) do
      lambda.stub_responses(:list_tags, tags_stub)
    end

    context 'with the suppress_log_subscribe tag' do
      let(:tags_stub) do
        lambda.stub_data(
          :list_tags,
          tags: {
            'cloudwatch_loggly_suppress_subscribe' => 'true'
          }
        )
      end

      it 'returns true' do
        expect(subject.skip?).to be true
      end
    end

    context 'when the subscription is up to date' do
      let(:filter_stub) do
        cloudwatch.stub_data(
          :describe_subscription_filters,
          subscription_filters: [
            {
              filter_pattern: '',
              destination_arn: destination_arn
            }
          ]
        )
      end

      before(:each) do
        cloudwatch.stub_responses(:describe_subscription_filters, filter_stub)
      end

      it 'returns true' do
        expect(subject.skip?).to be true
      end
    end

    context 'when the log group is not found' do
      before(:each) do
        cloudwatch.stub_responses(
          :describe_subscription_filters,
          Aws::CloudWatchLogs::Errors::ResourceNotFoundException.new(
            'test',
            'test'
          )
        )
      end

      it 'returns true' do
        expect(subject.skip?).to be true
      end
    end

    context 'when the filter pattern is not up to date' do
      let(:filter_stub) do
        cloudwatch.stub_data(
          :describe_subscription_filters,
          subscription_filters: [
            {
              filter_pattern: 'no.match',
              destination_arn: destination_arn
            }
          ]
        )
      end

      before(:each) do
        cloudwatch.stub_responses(:describe_subscription_filters, filter_stub)
      end

      it 'returns false' do
        expect(subject.skip?).to be false
      end
    end

    context 'when the destination arn is not up to date' do
      let(:filter_stub) do
        cloudwatch.stub_data(
          :describe_subscription_filters,
          subscription_filters: [
            {
              filter_pattern: '',
              destination_arn: function_one_arn
            }
          ]
        )
      end

      before(:each) do
        cloudwatch.stub_responses(:describe_subscription_filters, filter_stub)
      end

      it 'returns false' do
        expect(subject.skip?).to be false
      end
    end
  end

  describe '.all' do
    context 'where there is 1 page of results' do
      before(:each) do
        lambda.stub_responses(:list_functions, functions_stub)
      end

      it 'returns an array of Subscribe::Lambda::Function instances' do
        data = described_class.all(lambda)
        expect(data.size).to eq(2)
        expect(data.first).to be_a(described_class)
      end
    end

    context 'where there are 2 pages of results' do
      let(:functions_stub) { lambda.stub_data(:list_functions, functions: functions, next_marker: 'abcdefg') }
      let(:more_functions_stub) { lambda.stub_data(:list_functions, functions: more_functions) }

      before(:each) do
        lambda.stub_responses(:list_functions, [functions_stub, more_functions_stub])
      end

      it 'returns an array of Subscribe::Lambda::Function instances' do
        data = described_class.all(lambda)
        expect(data.size).to eq(3)
        expect(data.last).to be_a(described_class)
      end
    end
  end

  describe '.subscribe_all' do
    let(:log_group_one_subscription) do
      cloudwatch.stub_data(
        :describe_subscription_filters,
        subscription_filters: [
          {
            filter_pattern: '',
            destination_arn: destination_arn
          }
        ]
      )
    end
    let(:log_group_two_subscription) do
      cloudwatch.stub_data(
        :describe_subscription_filters,
        subscription_filters: [
          { filter_pattern: 'no.match' },
          destination_arn: destination_arn
        ]
      )
    end

    before(:each) do
      lambda.stub_responses(:list_functions, functions_stub)
      lambda.stub_responses(:list_tags, tags_stub)
      cloudwatch.stub_responses(
        :describe_subscription_filters,
        ->(context) do
          if context.params[:log_group_name].include?('one')
            log_group_one_subscription
          else
            log_group_two_subscription
          end
        end
      )
    end

    it 'returns a hash of metadata included skipped and changed elements' do
      value = described_class.subscribe_all!(lambda, cloudwatch)
      expect(value.fetch(:changed)).to eq(['two'])
      expect(value.fetch(:skipped)).to eq(['one'])
    end

    describe 'subscriptions' do
      context 'when hitting throttling exceptions' do
        before(:each) do
          allow(cloudwatch).to receive(:describe_subscription_filters).and_raise(
            Aws::CloudWatchLogs::Errors::ThrottlingException.new('test', 'test')
          )
        end

        it 'retries method 3 times for each function' do
          described_class.subscribe_all!(lambda, cloudwatch)
          expect(cloudwatch).to have_received(:describe_subscription_filters).exactly(6).times
        end
      end
    end
  end
end
