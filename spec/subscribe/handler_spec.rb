# frozen_string_literal: true

describe Subscribe do
  context '.handle' do
    before(:each) do
      prepare_environment!
      Aws.config[:lambda] = {
        stub_responses: {
          list_functions: {
            functions: [
              {
                function_name: 'test',
                function_arn: 'arn:aws:lambda:us-west-2:123456789012:function:One'
              }
            ]
          },
          list_tags: {
            tags: { 'test' => 'true' }
          }
        }
      }
      Aws.config[:cloudwatchlogs] = {
        stub_responses: {
          describe_subscription_filters: {
            subscription_filters: []
          },
          put_subscription_filter: {}
        }
      }
    end

    it 'returns a hash of metadata' do
      value = described_class.handle(event: {}, context: {})
      expect(value.fetch(:changed)).to eq(['test'])
      expect(value.fetch(:skipped)).to eq([])
    end
  end
end
