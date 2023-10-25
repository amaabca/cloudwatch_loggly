# frozen_string_literal: true

describe Push do
  describe '.handle' do
    let(:event) { JSON.parse(read_fixture('push/event.json')) }
    let(:message) { read_fixture('push/decoded.json') }

    before(:each) do
      ENV['REGION'] = 'test'
      allow_any_instance_of(Push::Cloudwatch::Event).to receive(:get_lambda_tags).and_return(
        'cloudwatch_loggly_tag_app_name' => 'TEST_APP_NAME'
      )
      prepare_environment!
      stub_loggly_push_bulk(messages: [message])
    end

    after(:each) do
      ENV['REGION'] = ''
    end

    it 'returns the response body' do
      value = Push.handle(event: event, context: nil)
      expect(value).to eq('{"success":true}')
    end
  end
end
