require 'robe/client/app'
require 'robe/client/router'
require 'robe/common/state/stores/array'
require 'todo-example/client/components/page'

# array stores wrap a state which is an array

TODOS = Todos.new

class TodoApp < Robe::Client::App
  def initialize
    super Page.new
  end

  def done_scope
    scope = router.path.split('/').last
    scope.nil? || scope.empty? ? 'all' : scope
  end

  def done_states
    case done_scope
    when 'all';     [true, false]
    when 'active';  [false]
    when 'done';    [true]
    else fail
    end
  end

end

TodoApp.new.mount
