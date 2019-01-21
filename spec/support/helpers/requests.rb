module Helpers
  module Requests
    def stub_loggly_push_initial
      stub_request(:post, loggly_url_for('inputs/1234/'))
    end

    def stub_loggly_push(opts = {})
      stub_loggly_push_initial
        .with(
          headers: {
            'X-LOGGLY-TAG' => opts.fetch(:tags),
            'CONTENT-TYPE' => 'text/plain'
          },
          body: opts.fetch(:message)
        )
        .to_return(
          status: opts.fetch(:status) { 200 },
          body: opts.fetch(:body) { '{"success":true}' }
        )
    end

    def stub_loggly_push_bulk(opts = {})
      messages = opts.fetch(:messages)
      request_body = messages.map(&:chomp).join("\n")
      stub_request(:post, loggly_url_for('bulk/1234/'))
        .with(
          headers: { 'CONTENT-TYPE' => 'text/plain' },
          body: request_body
        )
        .to_return(
          status: opts.fetch(:status) { 200 },
          body: opts.fetch(:body) { '{"success":true}' }
        )
    end

    private

    def loggly_url_for(*path)
      URI.join(Push::Loggly::Client::HOST, *path).to_s
    end
  end
end
