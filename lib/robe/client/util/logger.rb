
module Robe
  class Logger
    [:fatal, :info, :warn, :debug, :error].each do |method_name|
      define_method(method_name) do |text, &block|
        text = block.call if block
        `console[method_name](text)`
      end
    end
  end

  module_function
  def logger
    @logger ||= Robe::Logger.new
  end
end


