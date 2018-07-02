require 'time' # extra Time methods in stdlib
require 'date'

if RUBY_PLATFORM == 'opal'
  class Date
    def to_date
      self
    end
  end

  class Time
    def to_date
      Date.new(year, month, day)
    end
  end

end

module YmdStr
  def ymd
    strftime('%Y%m%d')
  end
  
  def ymd_with_sep(sep)
    strftime("%Y#{sep}%m#{sep}%d")
  end
  
  def ymd_dash
    ymd_with_sep('-')
  end

  def ymd_slash
    ymd_with_sep('/')
  end
  
  def ymd_colon
    ymd_with_sep(':')
  end
  
  def ymd_dot
    ymd_with_sep('.')
  end
end

class Date
  include YmdStr
end

class Time
  include YmdStr
  def hms
    strftime('%H%M%S')
  end

  def ymdhms
    "#{ymd} #{hms}"
  end
  
  def ymdhms_with_sep(ymd_sep: nil, hms_sep: nil)
    ymd_sep ||= '-'
    hms_sep ||= ':'
    "#{ymd_with_sep(ymd_sep)} #{hms_with_sep(hms_sep)}"
  end

  def hms_with_sep(sep)
    strftime("%H#{sep}%M#{sep}%S")
  end
  
  def hms_dash
    hms_with_sep('-')
  end

  def hms_slash
    hms_with_sep('/')
  end
  
  def hms_colon
    hms_with_sep(':')
  end
  
  def hms_dot
    hms_with_sep('.')
  end  
end

class String
  def to_date
    if RUBY_PLATFORM == 'opal'
      Time.parse(self).to_date
    else
      Date.parse(self)  
    end
  end
end
