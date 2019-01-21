describe Subscribe::Lambda::Function do
  let(:tags) { { 'test' => 'true' } }
  let(:lambda) { Aws::Lambda::Client.new(stub_responses: true) }
  let(:cloudwatch) { Aws::CloudWatchLogs::Client.new(stub_responses: true) }
  let(:tags_stub) { lambda.stub_data(:list_tags, tags: tags) }
  let(:function_one_arn) { 'arn:aws:lambda:us-west-2:123456789012:function:One' }
  let(:function_two_arn) { 'arn:aws:lambda:us-west-2:123456789012:function:Two' }
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
            'suppress_log_subscribe' => 'true'
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
          subscription_filters: [{ filter_pattern: '' }]
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

    context 'when the subscription is not up to date' do
      let(:filter_stub) do
        cloudwatch.stub_data(
          :describe_subscription_filters,
          subscription_filters: [{ filter_pattern: 'no.match' }]
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
    before(:each) do
      lambda.stub_responses(:list_functions, functions_stub)
      lambda.stub_responses(:list_tags, tags_stub)
    end

    it 'returns an array of Subscribe::Lambda::Function instances' do
      data = described_class.all(lambda)
      expect(data.size).to eq(2)
      expect(data.first).to be_a(described_class)
    end
  end

  describe '.subscribe_all' do
    let(:log_group_one_subscription) do
      cloudwatch.stub_data(
        :describe_subscription_filters,
        subscription_filters: [{ filter_pattern: '' }]
      )
    end
    let(:log_group_two_subscription) do
      cloudwatch.stub_data(
        :describe_subscription_filters,
        subscription_filters: [{ filter_pattern: 'no.match' }]
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
  end
end
