module Robe
  module Client
    module Browser
      module Wrap
        module HTTP
          class Response

            def initialize(xhr)
              @xhr = xhr
            end

            def code
              `#@xhr.status`
            end

            def body
              `#@xhr.response`
            end

            def json
              if `#{body} !== undefined`
                @json ||= JSON.parse(body)
              end
            end

            def success?
              (200...400).cover?(code)
            end

            def fail?
              !success?
            end

          end
        end
      end
    end
  end
end
