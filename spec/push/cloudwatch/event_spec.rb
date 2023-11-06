# frozen_string_literal: true

describe Push::Cloudwatch::Event do
  let(:event) { JSON.parse(read_fixture('push/event.json')) }
  let(:message) { read_fixture('push/decoded.json') }
  subject { described_class.new(raw: event) }

  before(:each) do
    ENV['REGION'] = 'test'
  end

  after(:each) do
    ENV['REGION'] = ''
  end

  describe '#to_loggly!' do
    before(:each) do
      prepare_environment!
      stub_loggly_push_bulk(messages: [message])
    end

    it 'raises a webmock exception' do
      expect { subject.to_loggly! }.to raise_exception(WebMock::NetConnectNotAllowedError)
    end

    context 'when using stubbs' do
      before(:each) do
        allow(subject).to receive(:retry_opts).and_return(
          stub_responses: {
            list_tags: { 'tags': { 'cloudwatch_loggly_tag_app_name' => 'TEST_APP_NAME' } }
          }
        )
      end

      it 'returns the response' do
        value = subject.to_loggly!
        expect(value).to eq('{"success":true}')
      end

      context 'when throttling exception is thrown' do
        before(:each) do
          allow(Aws::Lambda::Client).to receive(:new).and_raise(
            Aws::Lambda::Errors::ThrottlingException.new('test', 'test')
          )
        end

        it 'raises exception when retry limit exceeded' do
          expect { subject.to_loggly! }.to raise_error(
            StandardError,
            'ThrottlingExceptionRetryLimitExceeded'
          )
        end
      end
    end
  end
end
