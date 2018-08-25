
require 'robe/client/browser/wrap/window'

module Robe
  module Client
    module Browser

      @window = Robe::Client::Browser::Wrap::Window
      def window
        @window
      end
    end

  end
end
