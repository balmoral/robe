require 'robe/common/util/date_time_ext'

# A class for storing and manipulating dates in yyyymmdd format.
# Does everything the Date class does and some more.
# NB Opal does not support all Ruby's stdlib Date methods -
# we handle a couple but don't expect completeness.

class Ymd
  DEFAULT_CENTURY = '20'

  # Days of week matching Date#wday
  # (not Date#cwday)
  SUNDAY    = 0
  MONDAY    = 1
  TUESDAY   = 2
  WEDNESDAY = 3
  THURSDAY  = 4
  FRIDAY    = 5
  SATURDAY  = 6

  if RUBY_PLATFORM == 'opal'
    DAYNAMES = %w(Sunday Monday Tuesday Wednesday Thursday Friday Saturday)
    ABBR_DAYNAMES = %w(Sun Mon Tue Wed Thu Fri Sat)
  else
    DAYNAMES = Date::DAYNAMES
    ABBR_DAYNAMES = Date::ABBR_DAYNAMES
  end

  # Returns a Ymd.
  # Returns nil if unable to convert.
  def self.try_convert(date)
    # order is crucial
    if date.is_a?(String)
      date.size == 0 ? nil : parse(date)
    elsif date.respond_to?(:to_date)
      new(date)
    else
      nil
    end
  end

  # Returns a Ymd.
  # Raises error if unable to convert.
  def self.convert(date)
    result = try_convert(date)
    unless result
      raise ArgumentError, 'argument must respond to #to_date or be a string which can be parsed by Date or Time'
    end
    result
  end

  # Returns a Ymd from parsing given string.
  # NB: opal Date.parse can't handle strings with
  # named months nor can it parse YYYYMMDD without
  # separators so under opal we use Time.parse
  # not Date.parse.
  # Time.parse or Date.parse may fail if invalid
  # string cannot be parsed.
  # If the string is 6 or 8 or 10 characters long,
  # we do a quick parse expecting
  # 'yymmdd' or 'yyyymmdd' or 'yyyy-mm-dd' respectively,
  # without any verification.
  # Otherwise we pass on to Date.parse or Time.parse.
  def self.parse(str)
    if str.size == 6 # 'yymmdd'
      new([DEFAULT_CENTURY + str[0,2], str[2,2], str[4,2]])
    elsif str.size == 8 # 'yyyymmdd'
      new([str[0,4], str[4,2], str[6,2]])
    elsif str.size == 10 # 'yyyy-mm-dd'
      new([str[0,4], str[5,2], str[8,2]])
    else
      if RUBY_PLATFORM == 'opal'
        new(Time.parse(str).to_date)
      else
        new(Date.parse(str))
      end
    end
  end

  # shift: day forward or back by -n or +n, defaults to 0
  def self.today(shift: nil)
    new(::Date.today + (shift || 0))
  end

  def self.tomorrow
    today(shift: 1)
  end

  def self.yesterday
    today(shift: -1)
  end

  def self.this_week(date: nil, first_wday: nil)
    start_of_week(date: date, first_wday: first_wday)
  end

  def self.next_week(date: nil, first_wday: nil, shift: nil)
    start_of_week(date: date, first_wday: first_wday, shift: shift || 1)
  end

  def self.prev_week(date: nil, first_wday: nil, shift: nil)
    start_of_week(date: date, first_wday: first_wday, shift: shift || -1)
  end

  # Returns Ymd of first day of week.
  # date: defaults to today
  # shift: week forward or back by -n or +n, defaults to 0
  # first_wday: defaults to 0 (Sunday)
  def self.start_of_week(date: nil, first_wday: nil, shift: nil)
    date ||= Date.today
    shift ||= 0
    first_wday ||= 0
    unless first_wday >= 0 && first_wday <= 6
      raise ArgumentError, 'first_wday must be 0..6'
    end
    adjust = date.wday - first_wday
    adjust += 7 if adjust < 0
    date = date - adjust
    date = date + shift * 7
    new(date)
  end

  def self.week_commencing(**args)
    start_of_week(**args)
  end

  def self.end_of_week(date: nil, first_wday: nil, shift: nil)
    start_of_week(date: date, first_wday: first_wday, shift: shift) + 6
  end

  def self.week_end(**args)
    end_of_week(**args)
  end

  # if no seed given, defaults to today
  def initialize(*args)
    seed = if args.size == 0
      Date.today
    elsif args.size == 1
      args[0]
    else
      args
    end
    @date = nil
    if seed.is_a?(Array) # ['1999', '12', '31'] or [1999, 12, 31]
      @ymd = "#{seed[0]}#{seed[1]}#{seed[2]}"
    elsif seed.is_a?(Ymd)
      @ymd = seed.ymd
      @date = seed.to_date
    elsif seed.is_a?(Hash)
      @ymd = "#{seed[:y] || seed[:year] || seed[:yyyy]}#{seed[:m] || seed[:month] || seed[:mm]}#{seed[:d] || seed[:day] || seed[:dd]}"
    elsif seed.respond_to?(:to_date)
      @date = seed.to_date
      @ymd = @date.strftime('%Y%m%d')
    else
      raise ArgumentError, 'seed must be a Ymd or respond_to #to_date'
    end
  end

  # Returns ymd string
  def ymd
    @ymd
  end

  def to_ymd
    self
  end

  def hash
    @ymd.hash
  end

  def ==(other)
    other.respond_to?(:ymd) ? @ymd == other.to_ymd.ymd : false
  end

  # other must be a Date or respond to #to_ymd
  def eql?(other)
    self == other
  end

  # other must respond to #to_ymd
  def <=>(other)
    @ymd <=> other.to_ymd.ymd
  end

  # other must respond to #to_ymd
  def <(other)
    @ymd < other.to_ymd.ymd
  end

  # other must respond to #to_ymd
  def <=(other)
    @ymd <= other.to_ymd.ymd
  end

  # other must respond to #to_ymd
  def >(other)
    @ymd > other.to_ymd.ymd
  end

  # other must respond to #to_ymd
  def >=(other)
    @ymd >= other.to_ymd.ymd
  end

  def to_s
    @ymd
  end

  def inspect
    @ymd
  end

  def yyyy
    @ymd[0,4]
  end

  def mm
    @ymd[4,2]
  end

  def dd
    @ymd[6,2]
  end

  def year
    yyyy.to_i
  end

  def month
    mm.to_i
  end

  def day
    dd.to_i
  end

  def start_of_week(first_wday: nil)
    self.class.start_of_week(date: self, first_wday: first_wday)
  end

  alias_method :week_commencing, :start_of_week

  def end_of_week(first_wday: nil)
    self.class.end_of_week(date: self, first_wday: first_wday)
  end

  alias_method :week_ending, :end_of_week

  def this_week(first_wday: nil)
    self.class.this_week(date: self, first_wday: first_wday)
  end

  def prev_week(first_wday: nil, shift: nil)
    self.class.prev_week(date: self, first_wday: first_wday, shift: shift)
  end

  def next_week(first_wday: nil, shift: nil)
    self.class.next_week(date: self, first_wday: first_wday, shift: shift)
  end

  def to_date
    @date ||= Date.new(year, month, day)
  end

  def to_datetime
    to_date.to_datetime
  end

  def to_time
    @time ||= to_date.to_time
  end

  def with_sep(sep)
    "#{yyyy}#{sep}#{mm}#{sep}#{dd}"
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

  def strftime(format)
    to_date.strftime(format)
  end

  def day_of_week
    wday
  end
  
  # Returns the name of day.
  # If relative_to is given it should respond to #to_date,
  # and a relative day name ('Today', 'Tomorrow', 'Yesterday')
  # may be returned.
  # If relative_to is not given, then a normal day name will
  # be returned, abbreviated if abbr is true (default false).
  # TODO: opal doesn't handle this argument set up
  def day_name(relative_to: nil, abbr: false)
    date = to_date
    if relative_to
      unless relative_to.respond_to?(:to_date)
        raise ArgumentError, 'relative_to must be nil, numeric, :today or respond to #to_date'
      end
      diff = date - relative_to.to_date
      case diff
        when 0; 'Today'
        when 1; 'Tomorrow'
        when -1; 'Yesterday'
        else
          diff > 1 ? "#{diff} Days After" : "#{diff} Days Before"
      end
    else
      date.strftime(abbr ? '%a': '%A')
    end
  end

  # analog of Date methods which return a new Date where argument can be a date or numeric
  %i[+ -].each do |method|
    define_method(method) do |arg|
      if arg.respond_to?(:to_date)
        to_date.send(method, arg.to_date)
      else
        self.class.new(to_date.send(method, arg))
      end
    end
  end

  # analog of Date methods which return a new Date where argument is numeric
  %i[<< >> next_day next_month next_year prev_day prev_month prev_year].each do |method|
    define_method(method) do |n|
      self.class.new(to_date.send(method, n))
    end
  end

  # analog of Date methods which return a new Date without arguments
  %i[england gregorian italy julian next succ].each do |method|
    define_method(method) do
      self.class.new(to_date.send(method))
    end
  end

  # delegated to #to_date comparisons
  %i[===].each do |method|
    define_method(method) do |other|
      to_date.send(method, other.to_date)
    end
  end

  # delegated to #to_date without arguments
  %i[
    ajd amjd asctime
    ctime cwday cweek cwyear
    day_fraction
    friday? gregorian?
    httpdate iso8601
    jd jisx0301 julian? ld leap?
    mday mdj mon monday?
    rfc2822 rfc822 rfc3339 rfc2822 rfc822
    saturday? start sunday?
    thursday? tuesday?
    wday wednesday?
    xmlschema iso8601
    yday
  ].each do |method|
    define_method(method) do
      to_date.send(method)
    end
  end

  # analog of Date methods with single date argument which
  # return an enumerator or enumerate a range via given block
  %i[downto upto].each do |method|
    define_method(method) do |limit, &block|
      limit = limit.to_date
      if block
        to_date.send(method, limit) do |date|
          block.call self.class.new(date)
        end
      else
        to_date.send(method, limit)
      end
    end
  end

  # analog of Date methods with single date argument and
  # optional step which return an enumerator or enumerate
  # a range via given block
  %i[step].each do |method|
    define_method(method) do |limit, step = 1, &block|
      limit = limit.to_date
      if block
        to_date.send(method, limit, step) do |date|
          block.call self.class.new(date)
        end
      else
        to_date.send(method, limit, step)
      end
    end
  end

end

class Time
  def to_ymd
    Ymd.new(self)
  end
end

class Date
  def to_ymd
    Ymd.new(self)
  end
end

class String
  def to_ymd
    Ymd.parse(self)
  end
end
