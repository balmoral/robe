# mostly cloned from Bowser::WebSocket - thanks to Jamie Gaskins (@jgaskins)
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
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.

require 'json'
require 'robe/common/sockets'
require 'robe/client/browser/websocket/incoming_message'
require 'robe/client/browser/websocket/close_event'

module Robe; module Client; module Browser
  class WebSocket

    EVENT_NAMES = %i(open error message close)

    def self.instance(url)
      @instance ||= new(url)
    end

    def initialize(url, auto_reconnect: true)
      # trace __FILE__, __LINE__, self, __method__, " url='#{url}' auto_reconnect=#{auto_reconnect}"
      @url = url
      @auto_reconnect = auto_reconnect
      init_handlers
      connect!
    end

    # Expects any object that JSON can be generated from.
    def send_message(message)
      json = JSON.generate(message)
      `#@native.send(#{json})`
      self
    end

    # On :open event will call handler with no args.
    #
    # On :close event will call block with CloseEvent.
    #
    # On :message event will call block with an IncomingMessage.
    #
    def on(event_name, &block)
      event_name = event_name.to_sym
      if EVENT_NAMES.include?(event_name)
        @handlers[event_name] << block
      else
        Robe.logger.warn "#{self.class.name} : #{event_name} is not one of the allowed WebSocket events: #{EVENT_NAMES}"
      end
    end

    def connected?
      @connected
    end

    def close(reason = `undefined`)
      # trace __FILE__, __LINE__, self, __method__, " reason => #{reason}"
      `#@native.close(reason)`
    end

    private


    def init_handlers
      @handlers ||= Hash.new { |h, k| h[k] = [] }
      on(:open) do
        # trace __FILE__, __LINE__, self, __method__, " websocket #{@url} : opened "
        @connected = true
      end
      on(:close) do |event|
        # trace __FILE__, __LINE__, self, __method__, " websocket #{@url} : closed => #{event}"
        @connected = false

        # RADICAL BUT EFFECTIVE!
        # If we lose the websocket connection to the server something nasty has happened
        # like the server going down. Force a home page reload, and browser will report
        # any problems.
        #
        $app.state.notify_web_socket_error
        # Robe.browser.delay(3000) do
        #   $app.router.reload_root
        # end
        
        # LESS DRAMATIC BUT PRONE TO PROBLEMS...
        #
        # if @auto_reconnect
        #   Robe.browser.delay(3000) {
        #     trace __FILE__, __LINE__, self, __method__, ' : calling connect!'
        #     connect!
        #   }
        # end
      end
      # a close event is always sent after an error, so no need to handle much here
      on(:error) do |error|
        trace __FILE__, __LINE__, self, __method__, " websocket #{@url} : error => #{error} "
        @connected = false
      end
    end
    
    def connect!
      @native = `new WebSocket(#{@url})`
      trace __FILE__, __LINE__, self, __method__, " : native => #{@native}"
      EVENT_NAMES.each do |event_name|
        trace __FILE__, __LINE__, self, __method__, " : adding event listener for #{event_name} "
        %x{
          #@native.addEventListener(event_name, function(event) {
            var ruby_event;

            if(event.constructor === CloseEvent) {
              rb_event = #{CloseEvent.new(`event`)};
            } else if(event.constructor === MessageEvent) {
              rb_event = #{IncomingMessage.new(`event`)};
            } else if(event.constructor === ErrorEvent) {
              rb_event = event;
            } else {
              rb_event = event;
            }
            #{
              # trace __FILE__, __LINE__, self, __method__, " : event_name=#{event_name} rb_event=#{`rb_event`} handlers=#{@handlers[event_name].map(&:class)}"
              @handlers[event_name].each do |handler|
                handler.call(`rb_event`)
              end
            }
          });
        }
      end
    end

  end

end end end
