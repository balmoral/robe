require 'robe/common/util/inflector'

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

  def eqv?(other, prec: 0)
    round(prec) == other.round(prec)
  end
end

module Enumerable
  def exclude?(v)
    !include?(v)
  end
end

class Hash
  def symbolize_keys
    result = {}
    each { |k, v|
      result[k.to_sym] = v.is_a?(Hash) ? v.symbolize_keys : v
    }
    result
  end

  def stringify_keys
    result = {}
    each { |k, v|
      result[k.to_s] = v.is_a?(Hash) ? v.stringify_keys : v
    }
    result
  end
end

class String
  # Returns self with newline character appended.
  def nl
    self << "\n"
  end

  # Returns self with comma character appended.
  def comma
    self << ','
  end

  # Returns self with tab character appended.
  def tab
    self << "\t"
  end

  # Returns string with all non-cap
  # characters removed.
  # EG 'John Smith' becomes 'JS'
  def caps_only
    gsub(/[[a-z],\d,\s,[:punct:]]/, '')
  end

  # Returns camel case string from a snake case.
  # e.g. 'john_smith' to 'JohnSmith'
  # if string is already camel case it should not change
  def camel_case
    sub(/^[a-z]/){|a|a.upcase}
    .gsub(/[_\-][a-z]/) {|a| a[1].upcase }
  end

  alias_method :camelize, :camel_case
  alias_method :camelcase, :camel_case

  # Takes a camel case or snake case string
  # (like a class name or method name respectively)
  # If the receiver is camel case then the result
  # inserts spaces before the caps, except for
  # the first, or when caps a sequential.
  # If the receiver is snake case then the result
  # has spaces substituted for underscores.
  # e.g. 'AbcDefGhi' => 'Abc Def Ghi'
  # e.g. 'AbcABC' => 'Abc ABC'
  def words
    gsub(/([a-z\d])([A-Z])/, '\1 \2')
    .gsub(/_/, ' ').single_space
  end

  def words_capitalize
    words.gsub(/\b(\w)/) {|w| w.upcase}
  end

  # Returns a string composed of the capitalized first characters
  # of each word in self.words.
  def acronym
    words
    .split(' ')
    .map {|w| w[0].upcase}
    .join
  end

  # Returns string 'john_smith' as 'John Smith'
  def underscore_to_upcase
    downcase
    .sub(/^\w/) {|w| w[0].upcase}
    .gsub(/_\w/) {|w| ' ' + w[1].upcase}
  end

  # Returns the snake_case (underscore) version of a CamelCase string.
  # If it is already underscore, it should return the same string.
  def snake_case
    # normalize spaces to underscores before camel casing
    single_space
    .gsub(/ /, '_')
    .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
    .gsub(/([a-z\d])([A-Z])/, '\1_\2')
    .single_underscore
    .downcase
  end

  alias_method :underscore, :snake_case

  # Returns a CamelCase string from a spaced
  # or snake_case (underscored) string.
  def camel_case
    # normalize to snake case before camel casing
    snake_case
    .sub(/^[a-z]/) {|a| a.upcase}
    .gsub(/[_\-][a-z]/) {|a| a[1].upcase }
  end

  alias_method :camelize, :camel_case

  # eg 'plus-sign'
  def kebab_case
    snake_case.gsub(/_/, '-')
  end

  # Returns string where all spaces between words are single only.
  # Leading & trailing spaces are stripped.
  def single_space
    gsub(/ {2,}/, ' ').strip
  end

  # Returns string where all underscores between words are single only.
  def single_underscore
    gsub(/_{2,}/, '_')
  end

  # from Volt
  def titleize
    gsub('_', ' ').split(' ').map(&:capitalize).join(' ')
  end

  # from Volt
  def headerize
    split(/[_-]/)
      .map { |new_str| new_str[0].capitalize + new_str[1..-1] }
      .join('-')
  end

  # Returns a string with commas added every 3 chars.
  def comma_numeric
    is_neg = self[0] == '-'
    min_len = 3 + (is_neg ? 1 : 0)
    if size <= min_len
      self
    else
      dot = index('.') || size
      if dot <= min_len
        self
      else
        first = self[0..(dot-1)]
        last = self[(dot+1)..-1]
        first = first[1..-1] if is_neg
        # fixed = first.reverse.gsub(/...(?=.)/, '\&,').reverse
        fixed = first.reverse.gsub(/...(?=.)/) {|s| "#{s},"}.reverse
        "#{is_neg ? '-' : ''}#{fixed}#{last ? '.' : ''}#{last}"
      end
    end.sub(' ,', '  ')
  end

  def number_of(n)
    "#{n} #{n == 1 ? self : pluralize}"
  end

  def strip_trailing_zeros
    strip.sub(/(\.0*[1-9]*)0*$/, '\1').sub(/\.$/,'').sub(/\.0*$/,'')
  end

  def pluralize(count = 0)
    count == 1 ? self : Robe::Inflector.pluralize(self)
  end

  def singularize
    Robe::Inflector.singularize(self)
  end

  def plural?
    pluralize == self
  end

  def singular?
    singularize == self
  end

end # String

