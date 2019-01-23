# frozen_string_literal: true

describe Push::Loggly::Exceptions::Base do
  describe '.from_http' do
    context 'with HTTP 200' do
      subject { OpenStruct.new(body: 'test', code: '200') }

      it 'returns the response body' do
        expect(described_class.from_http(subject)).to eq('test')
      end
    end

    context 'with HTTP 400' do
      subject { OpenStruct.new(body: 'test', code: '400') }

      it 'raises Push::Loggly::Exceptions::ClientError' do
        expect { described_class.from_http(subject) }.to raise_error(
          Push::Loggly::Exceptions::ClientError,
          'test'
        )
      end
    end

    context 'with HTTP 500' do
      subject { OpenStruct.new(body: 'test', code: '500') }

      it 'raises Push::Loggly::Exceptions::ServerError' do
        expect { described_class.from_http(subject) }.to raise_error(
          Push::Loggly::Exceptions::ServerError,
          'test'
        )
      end
    end
  end
end
