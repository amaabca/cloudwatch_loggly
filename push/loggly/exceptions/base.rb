module Push
  module Loggly
    module Exceptions
      class Base < StandardError
        class << self
          def from_http(response)
            code = response.code.to_i
            case
            when code < 400
              return response.body
            when code < 500
              raise ClientError, response.body
            else
              raise ServerError, response.body
            end
          end
        end
      end
    end
  end
end
