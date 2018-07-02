require 'robe/common/util/date_time_ext'

# A class for storing and manipulating times in yyyymmdd format.
# Does everything the Time class does.
# NB Opal does not support all Ruby's stdlib Time methods -
# we handle a couple but don't expect completeness.

class Hms

  # Returns a Hms.
  # Returns nil if unable to convert.
  def self.try_convert(time)
    # opal can't handle Timetime
    if time.respond_to?(:to_time)
      new(time)
    elsif time.is_a?(String)
      parse(time)
    else
      raise ArgumentError, 'argument must respond to #to_time or be a string which can be parsed Time'
    end
  end

  # Returns a Hms.
  # Raises error if unable to convert.
  def self.convert(time)
    result = try_convert(time)
    unless result
      raise ArgumentError, 'argument must respond to #to_time or be a string which can be parsed by Time or Time'
    end
    result
  end

  # Returns a Hms from parsing given string.
  # If the string is 4, 5, 6 or 8 characters long,
  # we do a quick parse expecting
  # 'hhmm', 'hh:mm', hhmmss', or 'hh:mm:ss' respectively.
  # Otherwise we pass on to Time.parse and 
  # pull out the hour, minute and second.
  def self.parse(str)
    if str.size == 4 # 'hhmm'
      new([str[0,2], str[2,2]])
    elsif str.size == 5 # 'hh:mm'
      new([str[0,2], str[3,2]])
    elsif str.size == 6 # 'hhmmss'
      new([str[0,2], str[2,2], str[4,2]])
    elsif str.size == 8 # 'hh:mm:ss'
      new([str[0,2], str[3,2], str[6,2]])
    else
      new(Time.parse(str))
    end
  end

  # shift: day forward or back by -n or +n, defaults to 0
  def self.now
    new(::Time.now)
  end

  # if no seed given, defaults to now
  def initialize(*args)
    seed = if args.size == 0
      Time.now
    elsif args.size == 1
      args[0]
    else
      args
    end
    @time = nil
    if seed.is_a?(Array) # ['12', '15', '29']
      @hms = "#{seed[0]}#{seed[1]}#{seed[2]}"
    elsif seed.is_a?(Hms)
      @hms = seed.hms
      @time = seed.to_time
    elsif seed.is_a?(Hash)
      @hms = "#{seed[:h] || seed[:hour] || seed[:hh]}#{seed[:m] || seed[:minute] || seed[:mm]}#{seed[:s] || seed[:second] || seed[:ss]}"
    elsif seed.respond_to?(:to_time)
      @time = seed.to_time
      @hms = @time.strftime('%H%M%S')
    else
      raise ArgumentError, 'seed must be a Hms or respond_to #to_time'
    end
  end

  # Returns hms string
  def hms
    @hms
  end

  def to_hms
    self
  end

  def hash
    @hms.hash
  end

  # other must be a Time or respond to #to_hms
  def ==(other)
    other.is_a?(Time) ? to_time == other : @hms == other.to_hms.hms
  end

  # other must be a Time or respond to #to_hms
  def eql?(other)
    self == other
  end

  # other must be a Time or respond to #to_hms
  def <=>(other)
    other.is_a?(Time) ? to_time <=> other : @hms <=> other.to_hms.hms
  end

  # other must be a Time or respond to #to_hms
  def <(other)
    other.is_a?(Time) ? to_time < other : @hms < other.to_hms.hms
  end

  # other must be a Time or respond to #to_hms
  def <=(other)
    other.is_a?(Time) ? to_time <= other : @hms <= other.to_hms.hms
  end

  # other must be a Time or respond to #to_hms
  def >(other)
    other.is_a?(Time) ? to_time > other : @hms > other.to_hms.hms
  end

  # other must be a Time or respond to #to_hms
  def >=(other)
    other.is_a?(Time) ? to_time >= other : @hms >= other.to_hms.hms
  end

  def to_s
    @hms
  end

  def inspect
    @hms
  end

  def hh
    @hms[0,4]
  end

  def mm
    @hms[4,2]
  end

  def ss
    @hms[6,2]
  end

  def hour
    hh.to_i
  end

  def minute
    mm.to_i
  end

  def second
    ss.to_i
  end

  def to_time(date: nil)
    date ||= Date.today
    Time.new(date.year, date.month, date.day, hour, minute, second)
  end

  def with_sep(sep)
    "#{hh}#{sep}#{mm}#{sep}#{ss}"
  end

  def with_dash
    with_sep('-')
  end

  def with_slash
    with_sep('/')
  end

  def with_colon
    with_sep(':')
  end

  def with_dot
    with_sep('.')
  end

  def strftime(format, date: nil)
    to_time(date: date).strftime(format)
  end

  # analog of Time methods which return a new Time where argument can be a time or numeric
  %i[+ -].each do |method|
    define_method(method) do |arg|
      if arg.respond_to?(:to_time)
        to_time.send(method, arg.to_time)
      else
        self.class.new(to_time.send(method, arg))
      end
    end
  end

end

class Time
  def to_hms
    Hms.new(self)
  end
end

class String
  def to_hms
    Hms.parse(self)
  end
end
