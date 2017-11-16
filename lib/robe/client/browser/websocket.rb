# mostly cloned from Bowser::WebSocket - thanks to Jamie Gaskins (@jgaskins)
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
      trace __FILE__, __LINE__, self, __method__, " url='#{url}' auto_reconnect=#{auto_reconnect}"
      @url = url
      @auto_reconnect = auto_reconnect
      init_native
      init_handlers
    end

    # Expects any object that can JSON can be generated from.
    def send_message(message)
      `#@native.send(#{JSON.generate(message)})`
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

    def reconnect!
      init_native
    end

    def close(reason = `undefined`)
      `#@native.close(reason)`
    end

    private

    def init_handlers
      @handlers ||= Hash.new { |h, k| h[k] = [] }
      on(:open) do
        trace __FILE__, __LINE__, self, __method__, " websocket #{@url} opened "
        @connected = true
      end
      on(:close) do
        trace __FILE__, __LINE__, self, __method__, " websocket #{@url} closed "
        @connected = false
        if @auto_reconnect
          Robe.browser.delay(1) {
            trace __FILE__, __LINE__, self, __method__, " : calling reconnect"
            reconnect!
          }
        end
      end
      on(:error) do |error|
        trace __FILE__, __LINE__, self, __method__, " websocket #{@url} got error #{error} "
        @connected = false
      end
    end
    
    def init_native
      @native = `new WebSocket(#{@url})`
      EVENT_NAMES.each do |event_name|
        %x{
          #@native["on" + #{event_name}] = function(event) {
            var ruby_event;

            if(event.constructor === CloseEvent) {
              ruby_event = #{CloseEvent.new(`event`)};
            } else if(event.constructor === MessageEvent) {
              ruby_event = #{IncomingMessage.new(`event`)};
            } else if(event.constructor === ErrorEvent) {
              ruby_event = event;
            } else {
              ruby_event = event;
            }
            #{
              trace __FILE__, __LINE__, self, __method__, " : event_name=#{event_name} ruby_event=#{`ruby_event`}"
              @handlers[event_name].each do |handler|
                handler.call(`ruby_event`)
              end
            }
          };
        }
      end
    end

  end

end end end
