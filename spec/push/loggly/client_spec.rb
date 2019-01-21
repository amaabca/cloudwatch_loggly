describe Push::Loggly::Client do
  before(:each) do
    prepare_environment!
  end

  describe '#push!' do
    subject { described_class.new(params) }
    let(:tags) { 'test' }
    let(:messages) do
      [
        "Message one\n",
        "Message two\n"
      ]
    end

    context 'with bulk == false' do
      let(:params) { { tags: tags, bulk: false, token: '1234' } }

      before(:each) do
        stub_loggly_push(message: messages.first, tags: tags)
        stub_loggly_push(message: messages.last, tags: tags)
      end

      it 'sends multiple HTTP requests for each message' do
        expect(subject).to receive(:request!).twice.and_call_original
        subject.push!(messages)
      end

      it 'returns an array of responses' do
        value = subject.push!(messages)
        expect(value).to eq([
          '{"success":true}',
          '{"success":true}'
        ])
      end
    end

    context 'with bulk == true' do
      let(:params) { { tags: tags, bulk: true, token: '1234' } }

      before(:each) do
        stub_loggly_push_bulk(messages: messages)
      end

      it 'makes a single HTTP request' do
        expect(subject).to receive(:request!).once.and_call_original
        subject.push!(messages)
      end

      it 'returns the response' do
        value = subject.push!(messages)
        expect(value).to eq('{"success":true}')
      end
    end

    context 'with errors' do
      let(:params) { { tags: tags, bulk: false, token: '1234' } }

      context 'with a timeout' do
        before(:each) do
          stub_loggly_push_initial.to_timeout
        end

        it 'raises Push::Loggly::Exceptions::Timeout' do
          expect { subject.push!(messages) }.to raise_error(
            Push::Loggly::Exceptions::Timeout
          )
        end
      end

      context 'with a 400 response' do
        before(:each) do
          stub_loggly_push(
            tags: tags,
            message: messages.first,
            body: '{"success":false}',
            status: 400
          )
        end

        it 'raises Push::Loggly::Exceptions::ClientError' do
          expect { subject.push!(messages) }.to raise_error(
            Push::Loggly::Exceptions::ClientError
          )
        end
      end

      context 'with a 500 response' do
        before(:each) do
          stub_loggly_push(
            tags: tags,
            message: messages.first,
            body: '{"success":false}',
            status: 500
          )
        end

        it 'raises Push::Loggly::Exceptions::ServerError' do
          expect { subject.push!(messages) }.to raise_error(
            Push::Loggly::Exceptions::ServerError
          )
        end
      end
    end
  end
end
