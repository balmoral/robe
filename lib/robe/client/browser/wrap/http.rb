module Robe; module Client; module Browser; module Wrap
  module HTTP
    module_function

    def fetch(url, method: :get, headers: {}, data: nil)
      promise = Robe::Promise.new
      request = Request.new(method, url)

      connect_events_to_promise request, promise

      request.send(data: data, headers: headers)

      promise
    end

    def upload(url, data, content_type: 'application/json', method: :post)
      promise = Robe::Promise.new
      request = Request.new(method, url)

      connect_events_to_promise request, promise

      request.send(data: data, headers: { 'Content-Type' => content_type })

      promise
    end

    def upload_files(url, files, key: 'files', key_suffix: '[]', method: :post)
      promise = Robe::Promise.new
      request = Request.new(method, url)

      connect_events_to_promise request, promise

      form = FormData.new
      files.each do |file|
        form.append "#{key}#{key_suffix}", file
      end

      request.send(data: form)

      promise
    end

    def upload_file(url, file, key: 'file', method: :post)
      upload_files(url, [file], key: key, key_suffix: nil, method: method)
    end

    def connect_events_to_promise(request, promise)
      request.on :load do
        promise.resolve request.response
      end
      request.on :error do |event|
        promise.reject Native(event)
      end
    end
  end
end end end end
