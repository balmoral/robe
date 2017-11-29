require 'robe/common/state/atom'

class Todo < Robe::State::Atom
  attr :id, :text, :done
end

class Todos < Robe::State::Atom
  attr :todos, :counts

  def initialize
    super(
      todos: Array.new,
      counts: {
        'all' => 0,
        'active' => 0,
        'done' => 0
      }
    )
  end

  def count(which = 'all')
    counts[which] || '?'
  end
  
  def add(id: todos.size + 1, text: "Todo ##{todos.size}", done: false)
    mutate! do
      todos << Todo.new(id: id, text: text, done: done)
      update_counts
      todos.last.observe { update_counts }
    end
  end

  def delete(todo)
    mutate! do
      todos.delete(todo)
      update_counts
    end
  end

  def all
    todos
  end

  def active
    todos.reject { |e| e.done }
  end

  def done
    todos.select { |e| e.done }
  end

  private

  def update_counts
    mutate! do
      counts['all'] = all.size
      counts['active'] = active.size
      counts['done'] = done.size
    end
  end
end
