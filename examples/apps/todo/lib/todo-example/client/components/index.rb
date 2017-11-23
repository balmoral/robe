class TodoApp < Robe::Client::App
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
                # if completed state not in scope then give a nil
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
      div.style(margin_bottom: 1.em)[
        todo_text(todo),
        todo_completed(todo),
        todo_delete(todo),
      ]
    end

    def todo_text(todo)
      input
      .value(todo.text)
      .style(width: 30.em)
      .on(
        input: ->(event) {
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
        click: ->{
          todo.mutate!(completed: !todo.completed)
        }
      )
    end

    def todo_delete(todo)
      button['X']
      .style(color: :red, font_size: :smaller, margin_left: 2.em)
      .on(
        click: ->{
          TODOS.delete(todo)
        }
      )
    end
  end
end