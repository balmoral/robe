require 'set'

module Robe; module Client; class App
  class Register

    def initialize
      @apps = Set.new
    end

    def each(&block)
      @apps.each &block
    end

    def <<(app)
      @apps << app
    end

    def render_all(&block)
      @apps.each do |app|
        app.render_current_url(&block)
      end
    end

    def delete(app)
      @apps.delete(app)
    end

  end
end end end
