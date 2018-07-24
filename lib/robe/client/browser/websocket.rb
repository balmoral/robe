require 'json'
require 'robe/common/sockets'
require 'robe/client/util/logger'
require 'robe/client/browser/websocket/incoming_message'
require 'robe/client/browser/websocket/close_event'

# ref: https://github.com/joewalnes/reconnecting-websocket/blob/master/reconnecting-websocket.js

module Robe; module Client; module Browser
  class WebSocket

    EVENT_NAMES = %i(open error message close)
    DEFAULT_TIMEOUT_INTERVAL = 2000 # milliseconds
    DEFAULT_MAX_RECONNECT_ATTEMPTS = 30
    DEFAULT_RECONNECT_INTERVAL = 1000 # milliseconds
    DEFAULT_MAX_RECONNECT_INTERVAL = 30000 # milliseconds
    DEFAULT_RECONNECT_DECAY = 1.5

    # TODO: determine ws or wss get from server/document - see Volt for how
    # TODO: allow apps to override or configure ?
    # TODO: in production this should be wss ?
    def self.default_url
      unless @url
        # The websocket url can be overridden by config.public.websocket_url
        url = "#{`document.location.host`}/socket"
        if url !~ /^wss?[:]\/\//
          if url !~ /^[:]\/\//
            # Add :// to the front
            url = "://#{url}"
          end
          ws_proto = (`document.location.protocol` == 'https:') ? 'wss' : 'ws'
          # Add wss? to the front
          url = "#{ws_proto}#{url}"
        end
        # trace __FILE__, __LINE__, self, __method__, " web socket url = #{url}"
        @url = url
      end
      @url
    end

    def self.instance(url = nil)
      if @instance
        unless url == @instance.url
          fail "web socket instance already with other url '#{@instance.url}' not '#{url}'"
        end
      else
        @instance = new(url || self.default_url)
      end
      @instance
    end

    attr_reader :url
    attr_reader :auto_reconnect, :timeout_interval
    attr_reader :max_reconnect_attempts, :reconnect_interval, :reconnect_decay

    def initialize(url,
      auto_reconnect: nil,
      timeout_interval: nil,
      max_reconnect_attempts: nil,
      reconnect_interval: nil,
      max_reconnect_interval: nil,
      reconnect_decay: nil
    )
      # trace __FILE__, __LINE__, self, __method__, " url='#{url}' auto_reconnect=#{auto_reconnect}"
      @url = url

      @auto_reconnect = auto_reconnect.nil? ? true : auto_reconnect
      @timeout_interval = timeout_interval || DEFAULT_TIMEOUT_INTERVAL
      @max_reconnect_attempts = max_reconnect_attempts || DEFAULT_MAX_RECONNECT_ATTEMPTS
      @reconnect_interval = reconnect_interval || DEFAULT_RECONNECT_INTERVAL
      @max_reconnect_interval = max_reconnect_interval || DEFAULT_MAX_RECONNECT_INTERVAL
      @reconnect_decay = reconnect_decay || DEFAULT_RECONNECT_DECAY
      
      @reconnect_attempt = 0
      @timeout = nil
      @timed_out = nil
      @forced_close = false

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
      @forced_close = true
      # trace __FILE__, __LINE__, self, __method__, " reason => #{reason}"
      `#@native.close(reason)`
    end

    private

    def connect!
      @native = `new WebSocket(#{@url})`
      # trace __FILE__, __LINE__, self, __method__, " : native => #{@native}"
      @timeout = Robe.browser.set_timeout(@timeout_interval) do
        # trace __FILE__, __LINE__, self, __method__, " : connection-timeout after #{@timeout_interval} seconds: #{@url}"
        @timed_out = true
        `#{@native}.close()` if @native
        @native = nil
        @timed_out = false
      end
      if @native
        EVENT_NAMES.each do |event_name|
          # trace __FILE__, __LINE__, self, __method__, " : adding event listener for #{event_name} "
          %x{
            #@native.addEventListener(event_name, function(event) {
              var rb_event;
              if(event_name === "open") {
                console.log(">>>>>>>>>>>>>>>>>>>>> clear socket open timeout <<<<<<<<<<<<<<<<<<<<<")
                clearTimeout(#{@timeout});
              } else if(event.constructor === CloseEvent) {
                rb_event = #{CloseEvent.new(`event`)};
              } else if(event.constructor === MessageEvent) {
                rb_event = #{IncomingMessage.new(`event`)};
              } else if(event.constructor === ErrorEvent) {
                rb_event = event;
              } else {
                rb_event = event;
              }
              #{
                @handlers[event_name].each do |handler|
                  # trace __FILE__, __LINE__, self, __method__, " : calling handler for event_name=#{event_name} rb_event=#{`rb_event`}"
                  handler.call(`rb_event`)
                end
              }
            });
          }
        end
      end
    end

    def reconnect!
      @reconnect_attempt += 1
      if @reconnect_attempt > @max_reconnect_attempts
        $app.state.notify_websocket_closed
        return
      end
      if @reconnect_attempt > 0
        $app.state.notify_websocket_reconnect(attempt: @reconnect_attempt)
      end
      delay = (@reconnect_interval.to_f * (@reconnect_decay ** @reconnect_attempt)).to_i
      delay = @max_reconnect_interval if delay > @max_reconnect_interval
      Robe.browser.delay(delay) do
        connect!
      end
    end

    def init_handlers
      @handlers ||= Hash.new { |h, k| h[k] = [] }
      on(:open) do
        # trace __FILE__, __LINE__, self, __method__, " websocket #{@url} : opened "
        @connected = true
        @reconnect_attempt = 0
        $app.state.notify_websocket_open
      end
      on(:close) do |event|
        # trace __FILE__, __LINE__, self, __method__, " websocket #{@url} : closed => #{event}"
        @connected = false
        if @auto_reconnect && !@forced_close
          reconnect!
        else
          $app.state.notify_websocket_closed
        end
      end
      # a close event is always sent after an error, so no need to handle much here
      on(:error) do |error|
        $app.state.notify_websocket_error(error)
        # trace __FILE__, __LINE__, self, __method__, " websocket #{@url} : error => #{error} "
        @connected = false
      end
      on(:message) do |message|
        # trace __FILE__, __LINE__, self, __method__, " websocket #{@url} : message => #{message.data} "
      end
    end


  end

end end end
