describe Push do
  describe '.handle' do
    let(:event) { JSON.parse(read_fixture('push/event.json')) }
    let(:message) { read_fixture('push/decoded.json') }

    before(:each) do
      prepare_environment!
      stub_loggly_push_bulk(messages: [message])
    end

    it 'returns the response body' do
      value = Push.handle(event: event, context: nil)
      expect(value).to eq('{"success":true}')
    end
  end
end
