
class Object
  def to_html
    to_s
  end
end

class Numeric
  def px;   "#{self}px"  end
  def em;   "#{self}em"  end
  def rem;  "#{self}rem" end
  def pc;   "#{self}%"   end
  def vh;   "#{self}vh"  end
  def hex;  "#%X" % self end
end