require 'robe/common/redux/atom'
require 'robe/client/app/user'

module Robe
  module Client
    class App
      class State < Robe::Redux::Atom

        attr :user
        attr :sign_in_error

        def user?
          !!user
        end

      end
    end
  end
end