require 'robe/common/util'

# a crude way of specifying/configuring DOM component/element
# TODO: this is legacy, needs work and refactoring

module Robe; module Client; module DOM
  class Stub
    include Robe::Util

    # options
    #
    # :value       # object appropriate to type or proc(context) or proc(value) or proc(context, value)
    # :sort_value  # object appropriate to type or proc(context) or proc(value) or proc(context, value)
    # :type        # :container, :media, :string, :integer, :decimal, :bool, :count, :percent, :sign, :date
    # :css         # string with valid css classes or proc(value) or proc(context, value)
    # :style       # { } hash of styles per Clearwater or proc(value) or proc(context, value)
    # :format      # string or proc(value) or proc(context, value) for :decimal, :percent, :date
    # :comma       # boolean for numeric values (default true)
    # :events      # { click: ->{ clicked }, ... } - hash or proc(value) or proc(context, value)
    #              # event names per 'developer.mozilla.org/en-US/docs/Web/Events'

    attr_reader :options, :type

    def initialize(**options)
      @options = options
      @type = @options[:type] ||= :container
      @options[:css] ||= ''
      @options[:style] ||= {}
      @options[:events] ||= {}
      @is_numeric = [:integer, :decimal, :percent, :count].include?(@type)
      @is_text = !(container? || media?)
      @options[:comma] = true if @options[:comma].nil?
      set_format_defaults
      set_css_defaults
      set_style_defaults
    end

    def container?
      @type == :container
    end

    def media?
      @type == :media
    end

    def text?
      @is_text
    end

    def date?
      @type == :date
    end

    def numeric?
      @is_numeric
    end

    # Returns a DOM element.
    # Context may be anything meaningful to procs.
    def to_element(parent, tag_name, args: {}, context: nil)
      args = args.merge(
        id: id(context: context, value: value),
        css: css(context: context, value: value),
        style: style(context: context, value: value),
        content: formatted_value(context: context)
      )
      Robe::Client::DOM.tag(parent, tag_name, **args)
    end

    # Context may be anything meaningful to procs.
    # Returned value will be formatted (if applicable).
    def value_and_attributes(context: nil)
      value = formatted_value(context: context)
      [
        value,
        {
          css:    css(context: context, value: value),
          style:  style(context: context, value: value),
        }.merge(
          events(context: context, value: value)
        )
      ]
    end

    def sort_value(context: nil)
      option(:sort_value, context: context)
    end

    def value(context: nil)
      option(:value, context: context)
    end

    def css(context: nil, value: nil)
      option(:css, context: context, value: value)
    end

    def id(context: nil, value: nil)
      option(:id, context: context, value: value) || hex_id
    end

    def style(context: nil, value: nil)
      option(:style, context: context, value: value)
    end

    def events(context: nil, value: nil)
      result = {}
      events = option(:events, context: context, value: value)
      if events && events.size > 0
        events.each do |event, proc|
          event = event[0,2] == 'on' ? event : :"on#{event}"
          result[event] = ->(_) {
            resolve(proc, context: context, value: nil)
          }
        end
      end
      result
    end

    def formatted_value(context: nil)
      v = value(context: context)
      if v
        if text?
          format = format(context: context, value: v)
          if numeric?
            comma_numeric(format % v.to_f)
          elsif date?
            parse_date(v).strftime(value)
          else
            v.to_s
          end
        else
          v
        end
      end
    end

    def format(context: nil, value: nil)
      option(:format, context: context, value: value)
    end

    def option(name, context: nil, value: nil)
      option = @options[name]
      resolve(option, context: context, value: value)
    end

    def resolve(thing, context: nil, value: nil)
      if Proc === thing
        if thing.arity == 2
          thing.call(context, value)
        elsif thing.arity == 1
          thing.call(value || context)
        else
          thing.call
        end
      else
        thing
      end
    end

    def comma_numeric(s)
      @options[:comma] ? s.comma_numeric : s
    end

    def parse_date(d)
      self.class.parse_date(d)
    end

    def self.parse_date(d)
      return d if d.is_a?(Date)
      # opal Date.parse can't handle strings with named months
      # nor can it parse YYYYMMDD without separators!
      if RUBY_PLATFORM == 'opal'
        t = Time.parse(d)
        Date.new(t.year, t.month, t.day)
      else
        Date.parse(d)
      end
    end

    private

    def set_tag_defaults
      @options[:tag] ||= 'div'
    end

    def set_style_defaults
      if text? && options[:style].nil?
        @options[:style] = case @options[:type]
          when :integer, :decimal, :count, :percent
            { text_align: 'right' }
          else
            { text_align: 'center' }
        end
      end
    end

    def set_css_defaults
      # ?
    end

    def set_format_defaults
      if text? && @options[:format].nil?
        @options[:format] = case @options[:type]
          when :decimal
            ->(v) {
              comma_numeric('%0.2f' % v)
            }
          when :integer, :count
            ->(v) {
              comma_numeric(v.to_i.to_s)
            }
          when :percent
            ->(v) {
              comma_numeric((v * 100).round(0).to_s)
            }
          when :sign
            ->(v) {
              if v == 0
                '0'
              else
                v < 0 ? '-' : '+'
              end
            }
          when :date
            ->(v) {
              v.strftime('%Y/%m/%d')
            }
          when :bool
            ->(v) {
              v ? 'T' : 'F'
            }
          else # :text, ...
            ->(v) {
              v.to_s
            }
        end
      end
    end

  end

end end end

