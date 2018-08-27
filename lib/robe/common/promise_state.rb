require 'robe/common/promise'
require 'robe/common/state/atom'

# Really simple but effective way of
# handling promise resolution through
# state changes.
#
# Especially useful in DOM to 'bind'
# elements to the state of the promise.
#

module Robe
  class PromiseState < Robe::State::Atom

    attr :state   # either :waiting, :success or :error
    attr :result  # if state == :success
    attr :error   # if state == :error

    def initialize(&block)
      super(state: :waiting, result: nil, error: nil)
      block.call.to_promise.then do |result|
        mutate!(state: :success, result: result)
      end.error do |error|
        mutate!(state: :error, error: error)
      end
    end
  end
end