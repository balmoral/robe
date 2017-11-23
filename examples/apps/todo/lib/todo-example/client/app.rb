require 'robe/client/app'
require 'robe/client/router'
require 'robe/common/util/unicode'

class App < Robe::Client::App
  include Robe::Unicode

  # array stores wrap a state which is an array
  class Todos < Robe::State::ArrayStore
  end

  TODOS = Todos.new

  class Todo < Robe::State::Atom
    attr :id, :text, :completed

    def initialize(**args)
      args[:completed] = false
      super(**args)
    end
  end


  class Header < Robe::Client::Component
    def render
      h1.style(margin_bottom: 1.em)[
        'RoBE Todos'
      ]
    end
  end

  class AddButton < Robe::Client::Component
    def render
      button[
        'Add todo...'
      ].on(click: ->{add_todo} )
    end

    def add_todo
      todo = Todo.new(id: TODOS.size, text: "todo ##{TODOS.size}")
      TODOS << todo
    end
  end

  class Index < Robe::Client::Component

    # router is provided by base component class
    def render
      div.style(margin_top: 1.em)[
        # whenever the route changes update the index
        bind(router) {
          # and whenever the TODOS change update the list
          div[
            bind(TODOS) {
              TODOS.map { |todo|
                bind(todo, :completed) {
                  if app.completed_states.include?(todo.completed)
                    todo_item(todo)
                  end
                }
              }
            }
          ]
        }
      ]
    end

    def todo_item(todo)
      trace __FILE__, __LINE__, self, __method__, " todo.id = #{todo.id} completed=#{todo.completed}"
      div.style(margin_bottom: 1.em)[
        todo_text(todo),
        todo_completed(todo),
        todo_delete(todo),
      ]
    end

    def todo_text(todo)
      input
      .id("todo-#{todo.id}-text")
      .value(todo.text)
      .style(width: 30.em)
      .on(
        input: -> (event) {
          todo.mutate!(text: event.target.value)
        }
      )
    end

    def todo_completed(todo)
      input
      .type(:checkbox)
      .checked(todo.completed)
      .style(margin_left: 2.em)
      .on(
        click: -> {
          todo.mutate!(completed: !todo.completed)
          trace __FILE__, __LINE__, self, __method__, " todo = #{todo}"
        }
      )
    end

    def todo_delete(todo)
      button['X']
      .style(color: :red, font_size: :smaller, margin_left: 2.em)
      .on(click: -> { TODOS.delete(todo) } )
    end

  end

  # navigation goes in the footer
  class Footer < Robe::Client::Component
    def render
      bind(router) {
        div[
          bind(TODOS) {
            if TODOS.size > 1
              div[
                button_link('all'),
                button_link('active'),
                button_link('completed')
              ]
            end
          }
        ]
      }
    end

    # A `link` sets the client-side router state
    # and updates the browser history. Use links
    # in place of anchor tags to prevent the
    # browser doing getting url from the server.
    def button_link(which)
      link.href("/#{which}")[
        button
        .disabled(app.completed_scope == which)
        .style(margin_right: 1.em, width: 6.em)[
          which.to_s.capitalize
        ]
      ]
    end
  end

  class Page < Robe::Client::Component
    def render
      div.style(margin_left: 2.em)[
        Header.new,
        AddButton.new,
        Index.new,
        Footer.new
      ]
    end
  end

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

::App.new.mount
