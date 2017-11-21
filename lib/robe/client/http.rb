# inspired and borrowed from clearwater-bowser - thanks to Jamie Gaskins (@jgaskins)
#
# Copyright (c) 2015 Jamie Gaskins
#
# MIT License
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:

# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.

require 'robe/common/trace'
require 'robe/common/promise'
require 'robe/client/http/request'
require 'robe/client/http/form_data'


module Robe; module Client
  module HTTP
    include Robe::Promise::Util
    extend Robe::Promise::Util

    module_function

    # DEPRECATED
    # returns promise
    def action(name, **params)
      name = name.to_s
      request = "/action/#{name}"
      unless params.empty?
        first = true
        params.each do |key, value|
          request = "#{request}#{first ? '?' : '&'}#{key}=#{value}"
          first = false
        end
      end
      # trace __FILE__,  __LINE__, self, __method__, "(#{name}, #{params}) | request => '#{request}'"
      fetch(request)
    end

    # returns promise
    def fetch(url, method: :get, headers: {}, data: nil)
      make_promise do |promise|
        request = Request.new(method, url)
        promise_on_response(request, promise)
        request.send(data: data, headers: headers)
      end
    end

    # returns promise
    def upload(url, data, content_type: 'application/json', method: :post)
      make_promise do | promise |
        request = Request.new(method, url)
        promise_on_response(request, promise)
        request.send(data: data, headers: { 'Content-Type' => content_type })
      end
    end

    # returns promise
    def upload_files(url, files, key: 'files', key_suffix: '[]', method: :post)
      make_promise do | promise |
        request = Request.new(method, url)
        promise_on_response(request, promise)
        form = FormData.new
        files.each do |file|
          form.append("#{key}#{key_suffix}", file)
        end
        request.send(data: form)
      end
    end

    # returns promise
    def upload_file(url, file, key: 'file', method: :post)
      upload_files(url, [file], key: key, key_suffix: nil, method: method)
    end

    def promise_on_response(request, promise)
      request.on :load do
        trace __FILE__, __LINE__, self, __method__, " response.class=#{request.response.class}"
        promise.resolve(request.response)
      end
      request.on :error do |event|
        promise.reject(Native(event))
      end
    end
  end
end end

$http = Robe::Client::HTTP