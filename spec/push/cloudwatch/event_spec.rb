describe Push::Cloudwatch::Event do
  let(:event) { JSON.parse(read_fixture('push/event.json')) }
  let(:message) { read_fixture('push/decoded.json') }
  subject { described_class.new(raw: event) }

  describe '#to_loggly!' do
    before(:each) do
      prepare_environment!
      stub_loggly_push_bulk(messages: [message])
    end

    it 'returns the response' do
      value = subject.to_loggly!
      expect(value).to eq('{"success":true}')
    end
  end
end
