# encoding: utf-8

# The Inflector transforms words from singular to plural, class names to table
# names, modularized class names to ones without, and class names to foreign
# keys. The default inflections for pluralization, singularization, and
# uncountable words are kept in inflections.rb.

module Robe
  module Inflector

    # Borrowed from Volt.
    #
    # A singleton instance of this class is yielded by Inflector.inflections,
    # which can then be used to specify additional inflection rules. If passed
    # an optional locale, rules for other languages can be specified. The
    # default locale is <tt>:en</tt>. Only rules for English are provided.
    #
    #   ActiveSupport::Inflector.inflections(:en) do |inflect|
    #     inflect.plural /^(ox)$/i, '\1\2en'
    #     inflect.singular /^(ox)en/i, '\1'
    #
    #     inflect.irregular 'octopus', 'octopi'
    #
    #     inflect.uncountable 'equipment'
    #   end
    #
    # New rules are added at the top. So in the example above, the irregular
    # rule for octopus will now be the first of the pluralization and
    # singularization rules that is runs. This guarantees that your rules run
    # before any of the rules that may already have been loaded.
    class Inflections
      @__instance__ = {}

      def self.instance(locale = :en)
        @__instance__[locale] ||= new
      end

      attr_reader :plurals, :singulars, :uncountables, :humans, :acronyms, :acronym_regex

      def initialize
        @plurals = []
        @singulars = []
        @uncountables = []
        @humans = []
        @acronyms = {}
        @acronym_regex = /(?=a)b/
      end

      # Private, for the test suite.
      def initialize_dup(orig) # :nodoc:
        %w(plurals singulars uncountables humans acronyms acronym_regex).each do |scope|
          instance_variable_set("@#{scope}", orig.send(scope).dup)
        end
      end

      # Specifies a new acronym. An acronym must be specified as it will appear
      # in a camelized string. An underscore string that contains the acronym
      # will retain the acronym when passed to +camelize+, +humanize+, or
      # +titleize+. A camelized string that contains the acronym will maintain
      # the acronym when titleized or humanized, and will convert the acronym
      # into a non-delimited single lowercase word when passed to +underscore+.
      #
      #   acronym 'HTML'
      #   titleize 'html'     #=> 'HTML'
      #   camelize 'html'     #=> 'HTML'
      #   underscore 'MyHTML' #=> 'my_html'
      #
      # The acronym, however, must occur as a delimited unit and not be part of
      # another word for conversions to recognize it:
      #
      #   acronym 'HTTP'
      #   camelize 'my_http_delimited' #=> 'MyHTTPDelimited'
      #   camelize 'https'             #=> 'Https', not 'HTTPs'
      #   underscore 'HTTPS'           #=> 'http_s', not 'https'
      #
      #   acronym 'HTTPS'
      #   camelize 'https'   #=> 'HTTPS'
      #   underscore 'HTTPS' #=> 'https'
      #
      # Note: Acronyms that are passed to +pluralize+ will no longer be
      # recognized, since the acronym will not occur as a delimited unit in the
      # pluralized result. To work around this, you must specify the pluralized
      # form as an acronym as well:
      #
      #    acronym 'API'
      #    camelize(pluralize('api')) #=> 'Apis'
      #
      #    acronym 'APIs'
      #    camelize(pluralize('api')) #=> 'APIs'
      #
      # +acronym+ may be used to specify any word that contains an acronym or
      # otherwise needs to maintain a non-standard capitalization. The only
      # restriction is that the word must begin with a capital letter.
      #
      #   acronym 'RESTful'
      #   underscore 'RESTful'           #=> 'restful'
      #   underscore 'RESTfulController' #=> 'restful_controller'
      #   titleize 'RESTfulController'   #=> 'RESTful Controller'
      #   camelize 'restful'             #=> 'RESTful'
      #   camelize 'restful_controller'  #=> 'RESTfulController'
      #
      #   acronym 'McDonald'
      #   underscore 'McDonald' #=> 'mcdonald'
      #   camelize 'mcdonald'   #=> 'McDonald'
      def acronym(word)
        @acronyms[word.downcase] = word
        @acronym_regex           = /#{@acronyms.values.join("|")}/
      end

      # Specifies a new pluralization rule and its replacement. The rule can
      # either be a string or a regular expression. The replacement should
      # always be a string that may include references to the matched data from
      # the rule.
      def plural(rule, replacement)
        @uncountables.delete(rule) if rule.is_a?(String)
        @uncountables.delete(replacement)
        @plurals.insert(0, [rule, replacement])
      end

      # Specifies a new singularization rule and its replacement. The rule can
      # either be a string or a regular expression. The replacement should
      # always be a string that may include references to the matched data from
      # the rule.
      def singular(rule, replacement)
        @uncountables.delete(rule) if rule.is_a?(String)
        @uncountables.delete(replacement)
        @singulars.insert(0, [rule, replacement])
      end

      # Specifies a new irregular that applies to both pluralization and
      # singularization at the same time. This can only be used for strings, not
      # regular expressions. You simply pass the irregular in singular and
      # plural form.
      #
      #   irregular 'octopus', 'octopi'
      #   irregular 'person', 'people'
      def irregular(singular, plural)
        @uncountables.delete(singular)
        @uncountables.delete(plural)

        s0    = singular[0]
        srest = singular[1..-1]

        p0    = plural[0]
        prest = plural[1..-1]

        if s0.upcase == p0.upcase
          plural(/(#{s0})#{srest}$/i, '\1' + prest)
          plural(/(#{p0})#{prest}$/i, '\1' + prest)

          singular(/(#{s0})#{srest}$/i, '\1' + srest)
          singular(/(#{p0})#{prest}$/i, '\1' + srest)
        else
          plural(/#{s0.upcase}(?i)#{srest}$/, p0.upcase + prest)
          plural(/#{s0.downcase}(?i)#{srest}$/, p0.downcase + prest)
          plural(/#{p0.upcase}(?i)#{prest}$/, p0.upcase + prest)
          plural(/#{p0.downcase}(?i)#{prest}$/, p0.downcase + prest)

          singular(/#{s0.upcase}(?i)#{srest}$/, s0.upcase + srest)
          singular(/#{s0.downcase}(?i)#{srest}$/, s0.downcase + srest)
          singular(/#{p0.upcase}(?i)#{prest}$/, s0.upcase + srest)
          singular(/#{p0.downcase}(?i)#{prest}$/, s0.downcase + srest)
        end
      end

      # Add uncountable words that shouldn't be attempted inflected.
      #
      #   uncountable 'money'
      #   uncountable 'money', 'information'
      #   uncountable %w( money information rice )
      def uncountable(*words)
        (@uncountables << words).flatten!
      end

      # Specifies a humanized form of a string by a regular expression rule or
      # by a string mapping. When using a regular expression based replacement,
      # the normal humanize formatting is called after the replacement. When a
      # string is used, the human form should be specified as desired (example:
      # 'The name', not 'the_name').
      #
      #   human /_cnt$/i, '\1_count'
      #   human 'legacy_col_person_name', 'Name'
      def human(rule, replacement)
        @humans.insert(0, [rule, replacement])
      end

      # Clears the loaded inflections within a given scope (default is
      # <tt>:all</tt>). Give the scope as a symbol of the inflection type, the
      # options are: <tt>:plurals</tt>, <tt>:singulars</tt>, <tt>:uncountables</tt>,
      # <tt>:humans</tt>.
      #
      #   clear :all
      #   clear :plurals
      def clear(scope = :all)
        case scope
          when :all
            @plurals = []
            @singulars = []
            @uncountables = []
            @humans = []
          else
            instance_variable_set "@#{scope}", []
        end
      end
    end

    # Yields a singleton instance of Inflector::Inflections so you can specify
    # additional inflector rules. If passed an optional locale, rules for other
    # languages can be specified. If not specified, defaults to <tt>:en</tt>.
    # Only rules for English are provided.
    #
    #   ActiveSupport::Inflector.inflections(:en) do |inflect|
    #     inflect.uncountable 'rails'
    #   end
    def self.inflections(locale = :en)
      if block_given?
        yield Inflections.instance(locale)
      else
        Inflections.instance(locale)
      end
    end

    # Returns the plural form of the word in the string.
    #
    # If passed an optional +locale+ parameter, the word will be
    # pluralized using rules defined for that language. By default,
    # this parameter is set to <tt>:en</tt>.
    #
    #   'post'.pluralize             # => "posts"
    #   'octopus'.pluralize          # => "octopi"
    #   'sheep'.pluralize            # => "sheep"
    #   'words'.pluralize            # => "words"
    #   'CamelOctopus'.pluralize     # => "CamelOctopi"
    #   'ley'.pluralize(:es)         # => "leyes"
    def self.pluralize(word, locale = :en)
      apply_inflections(word, inflections(locale).plurals)
    end

    # The reverse of +pluralize+, returns the singular form of a word in a
    # string.
    #
    # If passed an optional +locale+ parameter, the word will be
    # pluralized using rules defined for that language. By default,
    # this parameter is set to <tt>:en</tt>.
    #
    #   'posts'.singularize            # => "post"
    #   'octopi'.singularize           # => "octopus"
    #   'sheep'.singularize            # => "sheep"
    #   'word'.singularize             # => "word"
    #   'CamelOctopi'.singularize      # => "CamelOctopus"
    #   'leyes'.singularize(:es)       # => "ley"
    def self.singularize(word, locale = :en)
      apply_inflections(word, inflections(locale).singulars)
    end

    private

    # Applies inflection rules for +singularize+ and +pluralize+.
    #
    #  apply_inflections('post', inflections.plurals)    # => "posts"
    #  apply_inflections('posts', inflections.singulars) # => "post"
    def self.apply_inflections(word, rules)
      result = word.to_s.dup

      if word.empty? || inflections.uncountables.include?(result.downcase[/\b\w+\Z/])
        result
      else
        rules.each do |(rule, replacement)|
          if result.match(rule)
            result = result.sub(rule, replacement)
            break
          end
        end
        result
      end
    end

  end
end

Robe::Inflector.inflections(:en) do |inflect|
  inflect.plural(/$/, 's')
  inflect.plural(/s$/i, 's')
  inflect.plural(/^(ax|test)is$/i, '\1es')
  inflect.plural(/(octop|vir)us$/i, '\1i')
  inflect.plural(/(octop|vir)i$/i, '\1i')
  inflect.plural(/(alias|status)$/i, '\1es')
  inflect.plural(/(bu)s$/i, '\1ses')
  inflect.plural(/(buffal|tomat)o$/i, '\1oes')
  inflect.plural(/([ti])um$/i, '\1a')
  inflect.plural(/([ti])a$/i, '\1a')
  inflect.plural(/sis$/i, 'ses')
  inflect.plural(/(?:([^f])fe|([lr])f)$/i, '\1\2ves')
  inflect.plural(/(hive)$/i, '\1s')
  inflect.plural(/([^aeiouy]|qu)y$/i, '\1ies')
  inflect.plural(/(x|ch|ss|sh)$/i, '\1es')
  inflect.plural(/(matr|vert|ind)(?:ix|ex)$/i, '\1ices')
  inflect.plural(/^(m|l)ouse$/i, '\1ice')
  inflect.plural(/^(m|l)ice$/i, '\1ice')
  inflect.plural(/^(ox)$/i, '\1en')
  inflect.plural(/^(oxen)$/i, '\1')
  inflect.plural(/(quiz)$/i, '\1zes')

  inflect.singular(/s$/i, '')
  inflect.singular(/(ss)$/i, '\1')
  inflect.singular(/(n)ews$/i, '\1ews')
  inflect.singular(/([ti])a$/i, '\1um')
  inflect.singular(/((a)naly|(b)a|(d)iagno|(p)arenthe|(p)rogno|(s)ynop|(t)he)(sis|ses)$/i, '\1sis')
  inflect.singular(/(^analy)(sis|ses)$/i, '\1sis')
  inflect.singular(/([^f])ves$/i, '\1fe')
  inflect.singular(/(hive)s$/i, '\1')
  inflect.singular(/(tive)s$/i, '\1')
  inflect.singular(/([lr])ves$/i, '\1f')
  inflect.singular(/([^aeiouy]|qu)ies$/i, '\1y')
  inflect.singular(/(s)eries$/i, '\1eries')
  inflect.singular(/(m)ovies$/i, '\1ovie')
  inflect.singular(/(x|ch|ss|sh)es$/i, '\1')
  inflect.singular(/^(m|l)ice$/i, '\1ouse')
  inflect.singular(/(bus)(es)?$/i, '\1')
  inflect.singular(/(o)es$/i, '\1')
  inflect.singular(/(shoe)s$/i, '\1')
  inflect.singular(/(cris|test)(is|es)$/i, '\1is')
  inflect.singular(/^(a)x[ie]s$/i, '\1xis')
  inflect.singular(/(octop|vir)(us|i)$/i, '\1us')
  inflect.singular(/(alias|status)(es)?$/i, '\1')
  inflect.singular(/^(ox)en/i, '\1')
  inflect.singular(/(vert|ind)ices$/i, '\1ex')
  inflect.singular(/(matr)ices$/i, '\1ix')
  inflect.singular(/(quiz)zes$/i, '\1')
  inflect.singular(/(database)s$/i, '\1')

  inflect.irregular('person', 'people')
  inflect.irregular('man', 'men')
  inflect.irregular('child', 'children')
  inflect.irregular('sex', 'sexes')
  inflect.irregular('move', 'moves')
  # inflect.irregular('cow', 'kine')
  inflect.irregular('zombie', 'zombies')

  inflect.uncountable(%w(equipment information rice money species series fish sheep jeans police))
end
