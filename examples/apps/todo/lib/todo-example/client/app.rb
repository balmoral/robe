require 'robe/client/app'
require 'robe/client/router'
require 'robe/common/state/stores/array'
require 'todo-example/client/components/page'

# array stores wrap a state which is an array
TODOS = Robe::State::ArrayStore.new

class TodoApp < Robe::Client::App

  def initialize
    super Page.new
  end

  def completed_scope
    path = router.path.delete('/')
    path.empty? ? 'all' : path
  end

  def completed_states
    case completed_scope
    when 'all';       [true, false]
    when 'active';    [false]
    when 'completed'; [true]
    else fail
    end
  end
end

TodoApp.new.mount
